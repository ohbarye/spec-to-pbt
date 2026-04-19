# frozen_string_literal: true

require_relative "pbt_local"
require "rspec"
require_relative "payment_status_lifecycle_impl"
require_relative "payment_status_lifecycle_pbt_config" if File.exist?(File.expand_path("payment_status_lifecycle_pbt_config.rb", __dir__))

if File.exist?(File.expand_path("payment_status_lifecycle_pbt_config.rb", __dir__)) && !defined?(::PaymentStatusLifecyclePbtConfig)
  raise "Expected PaymentStatusLifecyclePbtConfig to be defined in payment_status_lifecycle_pbt_config.rb"
end

RSpec.describe "payment_status_lifecycle (stateful scaffold)" do
  # Regeneration-safe customization:
  # - edit payment_status_lifecycle_pbt_config.rb for SUT wiring and durable API mapping
  # - edit payment_status_lifecycle_impl.rb for implementation behavior
  # - edit this scaffold only for one-off refinements when needed

  module PaymentStatusLifecyclePbtSupport
    module_function

    def config
      defined?(::PaymentStatusLifecyclePbtConfig) ? ::PaymentStatusLifecyclePbtConfig : {}
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
    Pbt.assert(worker: :none, num_runs: 5, seed: 1) do
      Pbt.stateful(
        model: PaymentStatusLifecycleModel.new,
        sut: -> { PaymentStatusLifecyclePbtSupport.sut_factory(-> { PaymentStatusLifecycleImpl.new }).call },
        max_steps: 20
      )
    end
  end

  class PaymentStatusLifecycleModel
    def initialize
      @commands = [
        AuthorizeCommand.new,
        CaptureCommand.new,
        VoidCommand.new,
        RefundCommand.new
      ]
    end

    def initial_state
      default_state = 0 # TODO: replace with a domain-specific scalar model state
      PaymentStatusLifecyclePbtSupport.initial_state(default_state)
    end

    def commands(_state)
      @commands
    end
  end

  class AuthorizeCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :authorize
    end

    def arguments
      Pbt.nil
    end

    def applicable?(state)
      override = PaymentStatusLifecyclePbtSupport.applicable_override(name)
      return PaymentStatusLifecyclePbtSupport.call_applicable_override(override, state, nil) if override
      return true if PaymentStatusLifecyclePbtSupport.guard_failure_policy(name)
      guard_satisfied?(state)
    end

    def guard_satisfied?(state, _args = nil)
      state == 0 # inferred scalar lifecycle/status precondition for authorize
    end

    def next_state(state, args)
      override = PaymentStatusLifecyclePbtSupport.next_state_override(name)
      return PaymentStatusLifecyclePbtSupport.call_next_state_override(override, state, args) if override
      return state if PaymentStatusLifecyclePbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      1
    end

    def run!(sut, args)
      PaymentStatusLifecyclePbtSupport.before_run_hook&.call(sut)
      payload = PaymentStatusLifecyclePbtSupport.adapt_args(name, args)
      method_name = PaymentStatusLifecyclePbtSupport.resolve_method_name(name, :authorize)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(PaymentStatusLifecyclePbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = PaymentStatusLifecyclePbtSupport.adapt_result(name, result)
      PaymentStatusLifecyclePbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#p.status=0 implies#p'.status=1"
      # Analyzer hints: state_field="status", size_delta=nil, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:replace_like, command_confidence=:medium, guard_kind=:state_equals_constant, guard_field="status", guard_constant="0", rhs_source_kind=:constant, state_update_shape=:replace_constant
      # Related Alloy property predicates: Capture, Void, Refund
      # Related pattern hints: size
      # Derived verify hints: check_size_semantics, check_guard_failure_semantics
      policy = PaymentStatusLifecyclePbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if PaymentStatusLifecyclePbtSupport.call_verify_override(
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
        observed = PaymentStatusLifecyclePbtSupport.observed_state(sut)
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
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Payment#status
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      expected = 1
      raise "Expected replaced value for Payment#status" unless after_state == expected
      [sut, args] && nil
    end
  end

  class CaptureCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :capture
    end

    def arguments
      Pbt.nil
    end

    def applicable?(state)
      override = PaymentStatusLifecyclePbtSupport.applicable_override(name)
      return PaymentStatusLifecyclePbtSupport.call_applicable_override(override, state, nil) if override
      return true if PaymentStatusLifecyclePbtSupport.guard_failure_policy(name)
      guard_satisfied?(state)
    end

    def guard_satisfied?(state, _args = nil)
      state == 1 # inferred scalar lifecycle/status precondition for capture
    end

    def next_state(state, args)
      override = PaymentStatusLifecyclePbtSupport.next_state_override(name)
      return PaymentStatusLifecyclePbtSupport.call_next_state_override(override, state, args) if override
      return state if PaymentStatusLifecyclePbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      2
    end

    def run!(sut, args)
      PaymentStatusLifecyclePbtSupport.before_run_hook&.call(sut)
      payload = PaymentStatusLifecyclePbtSupport.adapt_args(name, args)
      method_name = PaymentStatusLifecyclePbtSupport.resolve_method_name(name, :capture)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(PaymentStatusLifecyclePbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = PaymentStatusLifecyclePbtSupport.adapt_result(name, result)
      PaymentStatusLifecyclePbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#p.status=1 implies#p'.status=2"
      # Analyzer hints: state_field="status", size_delta=nil, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:replace_like, command_confidence=:medium, guard_kind=:state_equals_constant, guard_field="status", guard_constant="1", rhs_source_kind=:constant, state_update_shape=:replace_constant
      # Related Alloy property predicates: Authorize, Void, Refund
      # Related pattern hints: size
      # Derived verify hints: check_size_semantics, check_guard_failure_semantics
      policy = PaymentStatusLifecyclePbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if PaymentStatusLifecyclePbtSupport.call_verify_override(
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
        observed = PaymentStatusLifecyclePbtSupport.observed_state(sut)
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
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Payment#status
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      expected = 2
      raise "Expected replaced value for Payment#status" unless after_state == expected
      [sut, args] && nil
    end
  end

  class VoidCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :void
    end

    def arguments
      Pbt.nil
    end

    def applicable?(state)
      override = PaymentStatusLifecyclePbtSupport.applicable_override(name)
      return PaymentStatusLifecyclePbtSupport.call_applicable_override(override, state, nil) if override
      return true if PaymentStatusLifecyclePbtSupport.guard_failure_policy(name)
      guard_satisfied?(state)
    end

    def guard_satisfied?(state, _args = nil)
      state == 1 # inferred scalar lifecycle/status precondition for void
    end

    def next_state(state, args)
      override = PaymentStatusLifecyclePbtSupport.next_state_override(name)
      return PaymentStatusLifecyclePbtSupport.call_next_state_override(override, state, args) if override
      return state if PaymentStatusLifecyclePbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      3
    end

    def run!(sut, args)
      PaymentStatusLifecyclePbtSupport.before_run_hook&.call(sut)
      payload = PaymentStatusLifecyclePbtSupport.adapt_args(name, args)
      method_name = PaymentStatusLifecyclePbtSupport.resolve_method_name(name, :void)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(PaymentStatusLifecyclePbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = PaymentStatusLifecyclePbtSupport.adapt_result(name, result)
      PaymentStatusLifecyclePbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#p.status=1 implies#p'.status=3"
      # Analyzer hints: state_field="status", size_delta=nil, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:replace_like, command_confidence=:medium, guard_kind=:state_equals_constant, guard_field="status", guard_constant="1", rhs_source_kind=:constant, state_update_shape=:replace_constant
      # Related Alloy property predicates: Authorize, Capture, Refund
      # Related pattern hints: size
      # Derived verify hints: check_size_semantics, check_guard_failure_semantics
      policy = PaymentStatusLifecyclePbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if PaymentStatusLifecyclePbtSupport.call_verify_override(
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
        observed = PaymentStatusLifecyclePbtSupport.observed_state(sut)
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
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Payment#status
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      expected = 3
      raise "Expected replaced value for Payment#status" unless after_state == expected
      [sut, args] && nil
    end
  end

  class RefundCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :refund
    end

    def arguments
      Pbt.nil
    end

    def applicable?(state)
      override = PaymentStatusLifecyclePbtSupport.applicable_override(name)
      return PaymentStatusLifecyclePbtSupport.call_applicable_override(override, state, nil) if override
      return true if PaymentStatusLifecyclePbtSupport.guard_failure_policy(name)
      guard_satisfied?(state)
    end

    def guard_satisfied?(state, _args = nil)
      state == 2 # inferred scalar lifecycle/status precondition for refund
    end

    def next_state(state, args)
      override = PaymentStatusLifecyclePbtSupport.next_state_override(name)
      return PaymentStatusLifecyclePbtSupport.call_next_state_override(override, state, args) if override
      return state if PaymentStatusLifecyclePbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      4
    end

    def run!(sut, args)
      PaymentStatusLifecyclePbtSupport.before_run_hook&.call(sut)
      payload = PaymentStatusLifecyclePbtSupport.adapt_args(name, args)
      method_name = PaymentStatusLifecyclePbtSupport.resolve_method_name(name, :refund)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(PaymentStatusLifecyclePbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = PaymentStatusLifecyclePbtSupport.adapt_result(name, result)
      PaymentStatusLifecyclePbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#p.status=2 implies#p'.status=4"
      # Analyzer hints: state_field="status", size_delta=nil, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:replace_like, command_confidence=:medium, guard_kind=:state_equals_constant, guard_field="status", guard_constant="2", rhs_source_kind=:constant, state_update_shape=:replace_constant
      # Related Alloy property predicates: Authorize, Capture, Void
      # Related pattern hints: size
      # Derived verify hints: check_size_semantics, check_guard_failure_semantics
      policy = PaymentStatusLifecyclePbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if PaymentStatusLifecyclePbtSupport.call_verify_override(
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
        observed = PaymentStatusLifecyclePbtSupport.observed_state(sut)
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
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Payment#status
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      expected = 4
      raise "Expected replaced value for Payment#status" unless after_state == expected
      [sut, args] && nil
    end
  end

end