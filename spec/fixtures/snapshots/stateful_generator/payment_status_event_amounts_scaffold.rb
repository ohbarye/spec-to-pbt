# frozen_string_literal: true

require "pbt"
require "rspec"
require_relative "payment_status_event_amounts_impl"
require_relative "payment_status_event_amounts_pbt_config" if File.exist?(File.expand_path("payment_status_event_amounts_pbt_config.rb", __dir__))

if File.exist?(File.expand_path("payment_status_event_amounts_pbt_config.rb", __dir__)) && !defined?(::PaymentStatusEventAmountsPbtConfig)
  raise "Expected PaymentStatusEventAmountsPbtConfig to be defined in payment_status_event_amounts_pbt_config.rb"
end

unless Pbt.respond_to?(:stateful)
  loaded_pbt_version = defined?(Gem.loaded_specs) ? Gem.loaded_specs["pbt"]&.version&.to_s : nil
  detail = loaded_pbt_version ? "loaded pbt #{loaded_pbt_version}" : "loaded pbt version unknown"
  raise "Expected pbt >= 0.6.0 with Pbt.stateful (#{detail}). Install a compatible pbt release before running this scaffold."
end

RSpec.describe "payment_status_event_amounts (stateful scaffold)" do
  # Regeneration-safe customization:
  # - edit payment_status_event_amounts_pbt_config.rb for SUT wiring and durable API mapping
  # - edit payment_status_event_amounts_impl.rb for implementation behavior
  # - edit this scaffold only for one-off refinements when needed

  module PaymentStatusEventAmountsPbtSupport
    module_function
    ARGUMENTS_OVERRIDE_UNSET = Object.new.freeze

    KNOWN_TOP_LEVEL_KEYS = %i[sut_factory initial_state command_mappings verify_context before_run after_run state_reader].freeze
    KNOWN_COMMAND_KEYS = %i[method arg_adapter model_arg_adapter result_adapter arguments_override applicable_override next_state_override verify_override guard_failure_policy].freeze

    def config
      defined?(::PaymentStatusEventAmountsPbtConfig) ? ::PaymentStatusEventAmountsPbtConfig : {}
    end

    def validate_config!
      return if config.empty?

      unknown_top = config.keys - KNOWN_TOP_LEVEL_KEYS
      raise "Unknown config keys in PaymentStatusEventAmountsPbtConfig: #{unknown_top.inspect}. See docs/config-reference.md for valid keys." unless unknown_top.empty?

      config.fetch(:command_mappings, {}).each do |cmd_name, cmd_config|
        next unless cmd_config.is_a?(Hash)
        unknown_cmd = cmd_config.keys - KNOWN_COMMAND_KEYS
        raise "Unknown config keys in PaymentStatusEventAmountsPbtConfig command_mappings[#{cmd_name}]: #{unknown_cmd.inspect}. See docs/config-reference.md for valid keys." unless unknown_cmd.empty?
      end

      if !config.key?(:sut_factory)
        warn "Warning: PaymentStatusEventAmountsPbtConfig is missing :sut_factory (required). The scaffold will use a default factory."
      end

      if state_reader.nil?
        warn "Warning: PaymentStatusEventAmountsPbtConfig has no verify_context.state_reader configured. SUT state will not be compared against the model."
      end
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

  it "wires a stateful PBT scaffold" do
    PaymentStatusEventAmountsPbtSupport.validate_config!

    Pbt.assert(worker: :none, num_runs: 5, seed: 1) do
      Pbt.stateful(
        model: PaymentStatusEventAmountsModel.new,
        sut: -> { PaymentStatusEventAmountsPbtSupport.sut_factory(-> { PaymentStatusEventAmountsImpl.new }).call },
        max_steps: 20
      )
    end
  end

  class PaymentStatusEventAmountsModel
    def initialize
      @commands = [
        OpenCommand.new,
        SettleUnitCommand.new,
        CloseCommand.new
      ]
    end

    def initial_state
      default_state = { captures: [], status: 0, remaining_amount: 0, settled_amount: 0 } # TODO: replace with a domain-specific structured model state
      PaymentStatusEventAmountsPbtSupport.initial_state(default_state)
    end

    def commands(_state)
      @commands
    end
  end

  class OpenCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :open
    end

    def arguments
      overridden = PaymentStatusEventAmountsPbtSupport.call_arguments_override(name)
      return overridden unless overridden.equal?(PaymentStatusEventAmountsPbtSupport::ARGUMENTS_OVERRIDE_UNSET)
      Pbt.nil
    end

    def applicable?(state)
      override = PaymentStatusEventAmountsPbtSupport.applicable_override(name)
      return PaymentStatusEventAmountsPbtSupport.call_applicable_override(override, state, nil) if override
      return true if PaymentStatusEventAmountsPbtSupport.guard_failure_policy(name)
      guard_satisfied?(state)
    end

    def guard_satisfied?(state, _args = nil)
      state[:status] == 0 # inferred structured collection/status precondition for open
    end

    def next_state(state, args)
      override = PaymentStatusEventAmountsPbtSupport.next_state_override(name)
      return PaymentStatusEventAmountsPbtSupport.call_next_state_override(override, state, args) if override
      return state if PaymentStatusEventAmountsPbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      # Inferred transition target: Payment#captures
      state.merge(captures: state[:captures], status: 1, remaining_amount: state[:remaining_amount], settled_amount: state[:settled_amount])
    end

    def run!(sut, args)
      PaymentStatusEventAmountsPbtSupport.before_run_hook&.call(sut)
      payload = PaymentStatusEventAmountsPbtSupport.adapt_args(name, args)
      method_name = PaymentStatusEventAmountsPbtSupport.resolve_method_name(name, :open)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(PaymentStatusEventAmountsPbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = PaymentStatusEventAmountsPbtSupport.adapt_result(name, result)
      PaymentStatusEventAmountsPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#p.status=0 implies#p'.status=1 and#p'.captures=#p.captures and#p'.remaining_amount=#p.remaining_amount and#p'.settled_amount=#p.settled_amount"
      # Analyzer hints: state_field="captures", size_delta=0, transition_kind=:size_no_change, requires_non_empty_state=false, scalar_update_kind=nil, command_confidence=:medium, guard_kind=:state_equals_constant, guard_field="status", guard_constant="0", rhs_source_kind=:constant, state_update_shape=:preserve_size
      # Derived verify hints: check_guard_failure_semantics
      policy = PaymentStatusEventAmountsPbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if PaymentStatusEventAmountsPbtSupport.call_verify_override(
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
        observed = PaymentStatusEventAmountsPbtSupport.observed_state(sut)
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
      observed = PaymentStatusEventAmountsPbtSupport.observed_state(sut)
      if !observed.nil?
        expected_observed_state = after_state
        raise "Expected observed state to match model" unless observed == expected_observed_state
      end
      # Inferred collection target: Payment#captures
      before_items = before_state[:captures]
      after_items = after_state[:captures]
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      raise "Expected size to stay the same" unless after_items.length == before_items.length
      before_status = before_state[:status]
      after_status = after_state[:status]
      expected_status = 1
      raise "Expected replaced value for Payment#status" unless after_status == expected_status
      before_remaining_amount = before_state[:remaining_amount]
      after_remaining_amount = after_state[:remaining_amount]
      raise "Expected preserved value for Payment#remaining_amount" unless after_remaining_amount == before_remaining_amount
      before_settled_amount = before_state[:settled_amount]
      after_settled_amount = after_state[:settled_amount]
      raise "Expected preserved value for Payment#settled_amount" unless after_settled_amount == before_settled_amount
      # TODO: add concrete collection checks for Open
      [sut, args] && nil
    end
  end

  class SettleUnitCommand
    def name
      :settle_unit
    end

    def arguments
      overridden = PaymentStatusEventAmountsPbtSupport.call_arguments_override(name)
      return overridden unless overridden.equal?(PaymentStatusEventAmountsPbtSupport::ARGUMENTS_OVERRIDE_UNSET)
      Pbt.nil
    end

    def applicable?(state)
      override = PaymentStatusEventAmountsPbtSupport.applicable_override(name)
      return PaymentStatusEventAmountsPbtSupport.call_applicable_override(override, state, nil) if override
      return true if PaymentStatusEventAmountsPbtSupport.guard_failure_policy(name)
      guard_satisfied?(state)
    end

    def guard_satisfied?(state, _args = nil)
      state[:remaining_amount] > 0 # inferred structured collection/scalar guard for settle_unit
    end

    def next_state(state, args)
      override = PaymentStatusEventAmountsPbtSupport.next_state_override(name)
      return PaymentStatusEventAmountsPbtSupport.call_next_state_override(override, state, args) if override
      return state if PaymentStatusEventAmountsPbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      # Inferred transition target: Payment#captures
      delta = PaymentStatusEventAmountsPbtSupport.scalar_model_arg(name, args)
      state.merge(captures: state[:captures] + [1], status: state[:status], remaining_amount: state[:remaining_amount] - 1, settled_amount: state[:settled_amount] + 1)
    end

    def run!(sut, args)
      PaymentStatusEventAmountsPbtSupport.before_run_hook&.call(sut)
      payload = PaymentStatusEventAmountsPbtSupport.adapt_args(name, args)
      method_name = PaymentStatusEventAmountsPbtSupport.resolve_method_name(name, :settle_unit)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(PaymentStatusEventAmountsPbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = PaymentStatusEventAmountsPbtSupport.adapt_result(name, result)
      PaymentStatusEventAmountsPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#p.status=1 and#p.remaining_amount>0 implies#p'.status=#p.status and#p'.captures=add[#p.captures,1]and#p'.remaining_amount=sub[#p.remaining_amount,1]and#p'.settled_amount=add[#p.settled_amount,1]"
      # Analyzer hints: state_field="captures", size_delta=1, transition_kind=:append, requires_non_empty_state=true, scalar_update_kind=nil, command_confidence=:high, guard_kind=:non_empty, guard_field="remaining_amount", guard_constant=nil, rhs_source_kind=:unknown, state_update_shape=:append_like
      # Derived verify hints: respect_non_empty_guard, check_guard_failure_semantics
      policy = PaymentStatusEventAmountsPbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if PaymentStatusEventAmountsPbtSupport.call_verify_override(
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
        observed = PaymentStatusEventAmountsPbtSupport.observed_state(sut)
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
      observed = PaymentStatusEventAmountsPbtSupport.observed_state(sut)
      if !observed.nil?
        expected_observed_state = after_state
        raise "Expected observed state to match model" unless observed == expected_observed_state
      end
      # Inferred collection target: Payment#captures
      before_items = before_state[:captures]
      after_items = after_state[:captures]
      # Derived from related assertions/facts: respect the non-empty guard before removal-style checks
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      expected_size = before_items.length + 1
      raise "Expected size to increase by 1" unless after_items.length == expected_size
      before_status = before_state[:status]
      after_status = after_state[:status]
      raise "Expected preserved value for Payment#status" unless after_status == before_status
      before_remaining_amount = before_state[:remaining_amount]
      after_remaining_amount = after_state[:remaining_amount]
      raise "Expected decremented value for Payment#remaining_amount" unless after_remaining_amount == before_remaining_amount - 1
      before_settled_amount = before_state[:settled_amount]
      after_settled_amount = after_state[:settled_amount]
      raise "Expected incremented value for Payment#settled_amount" unless after_settled_amount == before_settled_amount + 1
      [sut, args] && nil
    end
  end

  class CloseCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :close
    end

    def arguments
      overridden = PaymentStatusEventAmountsPbtSupport.call_arguments_override(name)
      return overridden unless overridden.equal?(PaymentStatusEventAmountsPbtSupport::ARGUMENTS_OVERRIDE_UNSET)
      Pbt.nil
    end

    def applicable?(state)
      override = PaymentStatusEventAmountsPbtSupport.applicable_override(name)
      return PaymentStatusEventAmountsPbtSupport.call_applicable_override(override, state, nil) if override
      return true if PaymentStatusEventAmountsPbtSupport.guard_failure_policy(name)
      guard_satisfied?(state)
    end

    def guard_satisfied?(state, _args = nil)
      state[:status] == 1 # inferred structured collection/status precondition for close
    end

    def next_state(state, args)
      override = PaymentStatusEventAmountsPbtSupport.next_state_override(name)
      return PaymentStatusEventAmountsPbtSupport.call_next_state_override(override, state, args) if override
      return state if PaymentStatusEventAmountsPbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      # Inferred transition target: Payment#captures
      state.merge(captures: state[:captures], status: 2, remaining_amount: state[:remaining_amount], settled_amount: state[:settled_amount])
    end

    def run!(sut, args)
      PaymentStatusEventAmountsPbtSupport.before_run_hook&.call(sut)
      payload = PaymentStatusEventAmountsPbtSupport.adapt_args(name, args)
      method_name = PaymentStatusEventAmountsPbtSupport.resolve_method_name(name, :close)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(PaymentStatusEventAmountsPbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = PaymentStatusEventAmountsPbtSupport.adapt_result(name, result)
      PaymentStatusEventAmountsPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#p.status=1 implies#p'.status=2 and#p'.captures=#p.captures and#p'.remaining_amount=#p.remaining_amount and#p'.settled_amount=#p.settled_amount"
      # Analyzer hints: state_field="captures", size_delta=0, transition_kind=:size_no_change, requires_non_empty_state=false, scalar_update_kind=nil, command_confidence=:medium, guard_kind=:state_equals_constant, guard_field="status", guard_constant="1", rhs_source_kind=:constant, state_update_shape=:preserve_size
      # Derived verify hints: check_guard_failure_semantics
      policy = PaymentStatusEventAmountsPbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if PaymentStatusEventAmountsPbtSupport.call_verify_override(
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
        observed = PaymentStatusEventAmountsPbtSupport.observed_state(sut)
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
      observed = PaymentStatusEventAmountsPbtSupport.observed_state(sut)
      if !observed.nil?
        expected_observed_state = after_state
        raise "Expected observed state to match model" unless observed == expected_observed_state
      end
      # Inferred collection target: Payment#captures
      before_items = before_state[:captures]
      after_items = after_state[:captures]
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      raise "Expected size to stay the same" unless after_items.length == before_items.length
      before_status = before_state[:status]
      after_status = after_state[:status]
      expected_status = 2
      raise "Expected replaced value for Payment#status" unless after_status == expected_status
      before_remaining_amount = before_state[:remaining_amount]
      after_remaining_amount = after_state[:remaining_amount]
      raise "Expected preserved value for Payment#remaining_amount" unless after_remaining_amount == before_remaining_amount
      before_settled_amount = before_state[:settled_amount]
      after_settled_amount = after_state[:settled_amount]
      raise "Expected preserved value for Payment#settled_amount" unless after_settled_amount == before_settled_amount
      # TODO: add concrete collection checks for Close
      [sut, args] && nil
    end
  end

end