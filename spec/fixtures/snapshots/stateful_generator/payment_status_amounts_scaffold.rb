# frozen_string_literal: true

require "pbt"
require "rspec"
require_relative "payment_status_amounts_impl"
require_relative "payment_status_amounts_pbt_config" if File.exist?(File.expand_path("payment_status_amounts_pbt_config.rb", __dir__))

if File.exist?(File.expand_path("payment_status_amounts_pbt_config.rb", __dir__)) && !defined?(::PaymentStatusAmountsPbtConfig)
  raise "Expected PaymentStatusAmountsPbtConfig to be defined in payment_status_amounts_pbt_config.rb"
end

unless Pbt.respond_to?(:stateful)
  loaded_pbt_version = defined?(Gem.loaded_specs) ? Gem.loaded_specs["pbt"]&.version&.to_s : nil
  detail = loaded_pbt_version ? "loaded pbt #{loaded_pbt_version}" : "loaded pbt version unknown"
  raise "Expected pbt >= 0.5.1 with Pbt.stateful (#{detail}). Install a compatible pbt release before running this scaffold."
end

RSpec.describe "payment_status_amounts (stateful scaffold)" do
  # Regeneration-safe customization:
  # - edit payment_status_amounts_pbt_config.rb for SUT wiring and durable API mapping
  # - edit payment_status_amounts_impl.rb for implementation behavior
  # - edit this scaffold only for one-off refinements when needed

  module PaymentStatusAmountsPbtSupport
    module_function
    ARGUMENTS_OVERRIDE_UNSET = Object.new.freeze

    def config
      defined?(::PaymentStatusAmountsPbtConfig) ? ::PaymentStatusAmountsPbtConfig : {}
    end

    def sut_factory(default_factory)
      config.fetch(:sut_factory, default_factory)
    end

    def initial_state(default_state)
      config.fetch(:initial_state, default_state)
    end

    def command_config(command_name)
      config.fetch(:command_mappings, {}).fetch(command_name, {})
    end

    def arguments_override(command_name)
      command_config(command_name)[:arguments_override]
    end

    def call_arguments_override(command_name, state = ARGUMENTS_OVERRIDE_UNSET)
      override = arguments_override(command_name)
      return ARGUMENTS_OVERRIDE_UNSET unless override

      parameters = override.parameters
      if parameters.any? { |kind, _name| kind == :rest }
        return state.equal?(ARGUMENTS_OVERRIDE_UNSET) ? override.call : override.call(state)
      end

      required = parameters.count { |kind, _name| kind == :req }
      optional = parameters.count { |kind, _name| kind == :opt }
      provided = state.equal?(ARGUMENTS_OVERRIDE_UNSET) ? 0 : 1

      if provided >= required && provided <= required + optional
        return provided.zero? ? override.call : override.call(state)
      end

      if 0 >= required && 0 <= required + optional
        return override.call
      end

      raise ArgumentError, "arguments_override for command #{command_name.inspect} must accept 0 or 1 positional arguments"
    end

    def resolve_method_name(command_name, default_method_name)
      command_config(command_name).fetch(:method, default_method_name)
    end

    def adapt_args(command_name, args)
      settings = command_config(command_name)
      adapter = settings[:arg_adapter] || settings[:model_arg_adapter]
      adapter ? adapter.call(args) : args
    end

    def model_args(command_name, args)
      adapter = command_config(command_name)[:model_arg_adapter] || command_config(command_name)[:arg_adapter]
      adapter ? adapter.call(args) : args
    end

    def scalar_model_arg(command_name, args)
      payload = model_args(command_name, args)
      payload.is_a?(Array) && payload.length == 1 ? payload.first : payload
    end

    def adapt_result(command_name, result)
      adapter = command_config(command_name)[:result_adapter]
      adapter ? adapter.call(result) : result
    end

    def applicable_override(command_name)
      command_config(command_name)[:applicable_override]
    end

    def next_state_override(command_name)
      command_config(command_name)[:next_state_override]
    end

    def guard_failure_policy(command_name)
      command_config(command_name)[:guard_failure_policy]
    end

    def call_applicable_override(override, state, args)
      parameters = override.parameters
      if parameters.any? { |kind, _name| kind == :rest }
        override.call(state, args)
      else
        required = parameters.count { |kind, _name| kind == :req }
        optional = parameters.count { |kind, _name| kind == :opt }
        if 2 >= required && 2 <= required + optional
          override.call(state, args)
        elsif 1 >= required && 1 <= required + optional
          override.call(state)
        else
          override.call
        end
      end
    end

    def call_next_state_override(override, state, args)
      return nil unless override

      parameters = override.parameters
      if parameters.any? { |kind, _name| kind == :rest }
        override.call(state, args)
      else
        required = parameters.count { |kind, _name| kind == :req }
        optional = parameters.count { |kind, _name| kind == :opt }
        if 2 >= required && 2 <= required + optional
          override.call(state, args)
        elsif 1 >= required && 1 <= required + optional
          override.call(state)
        else
          override.call
        end
      end
    end

    def verify_override(command_name)
      command_config(command_name)[:verify_override]
    end

    def state_reader
      config.fetch(:verify_context, {})[:state_reader] || config[:state_reader]
    end

    def observed_state(sut)
      reader = state_reader
      reader ? reader.call(sut) : nil
    end

    def call_verify_override(command_name, **kwargs)
      override = verify_override(command_name)
      return false unless override

      payload = kwargs.merge(observed_state: observed_state(kwargs[:sut]))
      if override.parameters.any? { |kind, _name| kind == :keyrest }
        override.call(**payload)
      else
        accepted = override.parameters.filter_map do |kind, name|
          name if [:keyreq, :key].include?(kind)
        end
        accepted_payload = accepted.empty? ? {} : payload.select { |key, _value| accepted.include?(key) }
        override.call(**accepted_payload)
      end
      true
    end

    def before_run_hook
      config[:before_run]
    end

    def after_run_hook
      config[:after_run]
    end
  end

  it "wires a stateful PBT scaffold (customize before enabling)" do
    unless ENV["ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD"] == "1"
      skip "Set ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 after customizing the generated scaffold"
    end

    Pbt.assert(worker: :none, num_runs: 5, seed: 1) do
      Pbt.stateful(
        model: PaymentStatusAmountsModel.new,
        sut: -> { PaymentStatusAmountsPbtSupport.sut_factory(-> { PaymentStatusAmountsImpl.new }).call },
        max_steps: 20
      )
    end
  end

  class PaymentStatusAmountsModel
    def initialize
      @commands = [
        AuthorizeAmountCommand.new,
        CaptureAmountCommand.new,
        ResetCommand.new
      ]
    end

    def initial_state
      default_state = { status: 0, authorized_amount: 0, captured_amount: 0 } # TODO: replace with a domain-specific structured model state
      PaymentStatusAmountsPbtSupport.initial_state(default_state)
    end

    def commands(_state)
      @commands
    end
  end

  class AuthorizeAmountCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :authorize_amount
    end

    def arguments
      overridden = PaymentStatusAmountsPbtSupport.call_arguments_override(name)
      return overridden unless overridden.equal?(PaymentStatusAmountsPbtSupport::ARGUMENTS_OVERRIDE_UNSET)
      Pbt.integer
    end

    def applicable?(state)
      override = PaymentStatusAmountsPbtSupport.applicable_override(name)
      return PaymentStatusAmountsPbtSupport.call_applicable_override(override, state, nil) if override
      return true if PaymentStatusAmountsPbtSupport.guard_failure_policy(name)
      guard_satisfied?(state)
    end

    def guard_satisfied?(state, _args = nil)
      state[:status] == 0 # inferred scalar lifecycle/status precondition for authorize_amount
    end

    def next_state(state, args)
      override = PaymentStatusAmountsPbtSupport.next_state_override(name)
      return PaymentStatusAmountsPbtSupport.call_next_state_override(override, state, args) if override
      return state if PaymentStatusAmountsPbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      delta = PaymentStatusAmountsPbtSupport.scalar_model_arg(name, args)
      state.merge(status: 1, authorized_amount: state[:authorized_amount] + delta, captured_amount: state[:captured_amount])
    end

    def run!(sut, args)
      PaymentStatusAmountsPbtSupport.before_run_hook&.call(sut)
      payload = PaymentStatusAmountsPbtSupport.adapt_args(name, args)
      method_name = PaymentStatusAmountsPbtSupport.resolve_method_name(name, :authorize_amount)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(PaymentStatusAmountsPbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = PaymentStatusAmountsPbtSupport.adapt_result(name, result)
      PaymentStatusAmountsPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#p.status=0 implies#p'.status=1 and#p'.authorized_amount=add[#p.authorized_amount,amount]and#p'.captured_amount=#p.captured_amount"
      # Analyzer hints: state_field="status", size_delta=1, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:replace_like, command_confidence=:medium, guard_kind=:state_equals_constant, guard_field="status", guard_constant="0", rhs_source_kind=:constant, state_update_shape=:replace_constant
      # Related Alloy property predicates: CaptureAmount, Reset
      # Related pattern hints: size
      # Derived verify hints: check_size_semantics, check_guard_failure_semantics
      policy = PaymentStatusAmountsPbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if PaymentStatusAmountsPbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut,
        guard_failed: guard_failed,
        guard_failure_policy: policy
      )
      raise result if result.is_a?(StandardError) && !guard_failed
      if guard_failed
        observed = PaymentStatusAmountsPbtSupport.observed_state(sut)
        case policy
        when :no_op
          raise "Expected unchanged model state on guard failure" unless after_state == before_state
          raise "Expected unchanged observed state on guard failure" if !observed.nil? && observed != after_state
        when :raise
          raise "Expected guard failure to surface as an exception" unless result.is_a?(StandardError)
          raise "Expected unchanged model state on guard failure" unless after_state == before_state
          raise "Expected unchanged observed state on guard failure" if !observed.nil? && observed != after_state
        when :custom
          raise "guard_failure_policy :custom requires verify_override to assert invalid-path semantics"
        else
          raise "Unsupported guard_failure_policy: #{policy.inspect}"
        end
        return nil
      end
      observed = PaymentStatusAmountsPbtSupport.observed_state(sut)
      if !observed.nil?
        expected_observed_state = after_state
        raise "Expected observed state to match model" unless observed == expected_observed_state
      end
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Payment#status
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      delta = PaymentStatusAmountsPbtSupport.scalar_model_arg(name, args)
      before_status = before_state[:status]
      after_status = after_state[:status]
      expected_status = 1
      raise "Expected replaced value for Payment#status" unless after_status == expected_status
      before_authorized_amount = before_state[:authorized_amount]
      after_authorized_amount = after_state[:authorized_amount]
      raise "Expected incremented value for Payment#authorized_amount" unless after_authorized_amount == before_authorized_amount + delta
      before_captured_amount = before_state[:captured_amount]
      after_captured_amount = after_state[:captured_amount]
      raise "Expected preserved value for Payment#captured_amount" unless after_captured_amount == before_captured_amount
      [sut, args] && nil
    end
  end

  class CaptureAmountCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :capture_amount
    end

    def arguments(state)
      overridden = PaymentStatusAmountsPbtSupport.call_arguments_override(name, state)
      return overridden unless overridden.equal?(PaymentStatusAmountsPbtSupport::ARGUMENTS_OVERRIDE_UNSET)
      Pbt.integer(min: 1, max: state[:authorized_amount])
    end

    def applicable?(state, args)
      override = PaymentStatusAmountsPbtSupport.applicable_override(name)
      return PaymentStatusAmountsPbtSupport.call_applicable_override(override, state, args) if override
      return true if PaymentStatusAmountsPbtSupport.guard_failure_policy(name)
      guard_satisfied?(state, args)
    end

    def guard_satisfied?(state, args = nil)
      delta = PaymentStatusAmountsPbtSupport.scalar_model_arg(name, args)
      current_value = state[:authorized_amount]
      delta.is_a?(Numeric) && delta.positive? && delta <= current_value
    end

    def next_state(state, args)
      override = PaymentStatusAmountsPbtSupport.next_state_override(name)
      return PaymentStatusAmountsPbtSupport.call_next_state_override(override, state, args) if override
      return state if PaymentStatusAmountsPbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      delta = PaymentStatusAmountsPbtSupport.scalar_model_arg(name, args)
      state.merge(status: 2, authorized_amount: state[:authorized_amount] - delta, captured_amount: state[:captured_amount] + delta)
    end

    def run!(sut, args)
      PaymentStatusAmountsPbtSupport.before_run_hook&.call(sut)
      payload = PaymentStatusAmountsPbtSupport.adapt_args(name, args)
      method_name = PaymentStatusAmountsPbtSupport.resolve_method_name(name, :capture_amount)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(PaymentStatusAmountsPbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = PaymentStatusAmountsPbtSupport.adapt_result(name, result)
      PaymentStatusAmountsPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#p.authorized_amount>=amount implies#p'.status=2 and#p'.authorized_amount=sub[#p.authorized_amount,amount]and#p'.captured_amount=add[#p.captured_amount,amount]"
      # Analyzer hints: state_field="authorized_amount", size_delta=1, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:decrement_like, command_confidence=:medium, guard_kind=:arg_within_state, guard_field="authorized_amount", guard_constant=nil, rhs_source_kind=:arg, state_update_shape=:decrement
      # Related Alloy property predicates: AuthorizeAmount, Reset, NonNegativeAuthorized
      # Related pattern hints: size
      # Derived verify hints: check_size_semantics, check_non_negative_scalar_state, check_guard_failure_semantics
      policy = PaymentStatusAmountsPbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if PaymentStatusAmountsPbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut,
        guard_failed: guard_failed,
        guard_failure_policy: policy
      )
      raise result if result.is_a?(StandardError) && !guard_failed
      if guard_failed
        observed = PaymentStatusAmountsPbtSupport.observed_state(sut)
        case policy
        when :no_op
          raise "Expected unchanged model state on guard failure" unless after_state == before_state
          raise "Expected unchanged observed state on guard failure" if !observed.nil? && observed != after_state
        when :raise
          raise "Expected guard failure to surface as an exception" unless result.is_a?(StandardError)
          raise "Expected unchanged model state on guard failure" unless after_state == before_state
          raise "Expected unchanged observed state on guard failure" if !observed.nil? && observed != after_state
        when :custom
          raise "guard_failure_policy :custom requires verify_override to assert invalid-path semantics"
        else
          raise "Unsupported guard_failure_policy: #{policy.inspect}"
        end
        return nil
      end
      observed = PaymentStatusAmountsPbtSupport.observed_state(sut)
      if !observed.nil?
        expected_observed_state = after_state
        raise "Expected observed state to match model" unless observed == expected_observed_state
      end
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Payment#authorized_amount
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from related assertions/facts: keep non-negative scalar invariants aligned with the model state
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      delta = PaymentStatusAmountsPbtSupport.scalar_model_arg(name, args)
      before_status = before_state[:status]
      after_status = after_state[:status]
      expected_status = 2
      raise "Expected replaced value for Payment#status" unless after_status == expected_status
      raise "Expected non-negative value for Payment#status" unless after_status >= 0
      before_authorized_amount = before_state[:authorized_amount]
      after_authorized_amount = after_state[:authorized_amount]
      raise "Expected sufficient scalar state before decrement" unless delta <= before_state[:authorized_amount]
      raise "Expected decremented value for Payment#authorized_amount" unless after_authorized_amount == before_authorized_amount - delta
      raise "Expected non-negative value for Payment#authorized_amount" unless after_authorized_amount >= 0
      before_captured_amount = before_state[:captured_amount]
      after_captured_amount = after_state[:captured_amount]
      raise "Expected incremented value for Payment#captured_amount" unless after_captured_amount == before_captured_amount + delta
      raise "Expected non-negative value for Payment#captured_amount" unless after_captured_amount >= 0
      [sut, args] && nil
    end
  end

  class ResetCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :reset
    end

    def arguments
      overridden = PaymentStatusAmountsPbtSupport.call_arguments_override(name)
      return overridden unless overridden.equal?(PaymentStatusAmountsPbtSupport::ARGUMENTS_OVERRIDE_UNSET)
      Pbt.nil
    end

    def applicable?(state)
      override = PaymentStatusAmountsPbtSupport.applicable_override(name)
      return PaymentStatusAmountsPbtSupport.call_applicable_override(override, state, nil) if override
      return true if PaymentStatusAmountsPbtSupport.guard_failure_policy(name)
      guard_satisfied?(state)
    end

    def guard_satisfied?(state, _args = nil)
      state[:status] == 2 # inferred scalar lifecycle/status precondition for reset
    end

    def next_state(state, args)
      override = PaymentStatusAmountsPbtSupport.next_state_override(name)
      return PaymentStatusAmountsPbtSupport.call_next_state_override(override, state, args) if override
      return state if PaymentStatusAmountsPbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      state.merge(status: 0, authorized_amount: 0, captured_amount: 0)
    end

    def run!(sut, args)
      PaymentStatusAmountsPbtSupport.before_run_hook&.call(sut)
      payload = PaymentStatusAmountsPbtSupport.adapt_args(name, args)
      method_name = PaymentStatusAmountsPbtSupport.resolve_method_name(name, :reset)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(PaymentStatusAmountsPbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = PaymentStatusAmountsPbtSupport.adapt_result(name, result)
      PaymentStatusAmountsPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#p.status=2 implies#p'.status=0 and#p'.authorized_amount=0 and#p'.captured_amount=0"
      # Analyzer hints: state_field="status", size_delta=nil, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:replace_like, command_confidence=:medium, guard_kind=:state_equals_constant, guard_field="status", guard_constant="2", rhs_source_kind=:constant, state_update_shape=:replace_constant
      # Related Alloy property predicates: AuthorizeAmount, CaptureAmount
      # Related pattern hints: size
      # Derived verify hints: check_size_semantics, check_guard_failure_semantics
      policy = PaymentStatusAmountsPbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if PaymentStatusAmountsPbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut,
        guard_failed: guard_failed,
        guard_failure_policy: policy
      )
      raise result if result.is_a?(StandardError) && !guard_failed
      if guard_failed
        observed = PaymentStatusAmountsPbtSupport.observed_state(sut)
        case policy
        when :no_op
          raise "Expected unchanged model state on guard failure" unless after_state == before_state
          raise "Expected unchanged observed state on guard failure" if !observed.nil? && observed != after_state
        when :raise
          raise "Expected guard failure to surface as an exception" unless result.is_a?(StandardError)
          raise "Expected unchanged model state on guard failure" unless after_state == before_state
          raise "Expected unchanged observed state on guard failure" if !observed.nil? && observed != after_state
        when :custom
          raise "guard_failure_policy :custom requires verify_override to assert invalid-path semantics"
        else
          raise "Unsupported guard_failure_policy: #{policy.inspect}"
        end
        return nil
      end
      observed = PaymentStatusAmountsPbtSupport.observed_state(sut)
      if !observed.nil?
        expected_observed_state = after_state
        raise "Expected observed state to match model" unless observed == expected_observed_state
      end
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Payment#status
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      before_status = before_state[:status]
      after_status = after_state[:status]
      expected_status = 0
      raise "Expected replaced value for Payment#status" unless after_status == expected_status
      before_authorized_amount = before_state[:authorized_amount]
      after_authorized_amount = after_state[:authorized_amount]
      expected_authorized_amount = 0
      raise "Expected replaced value for Payment#authorized_amount" unless after_authorized_amount == expected_authorized_amount
      before_captured_amount = before_state[:captured_amount]
      after_captured_amount = after_state[:captured_amount]
      expected_captured_amount = 0
      raise "Expected replaced value for Payment#captured_amount" unless after_captured_amount == expected_captured_amount
      [sut, args] && nil
    end
  end

end