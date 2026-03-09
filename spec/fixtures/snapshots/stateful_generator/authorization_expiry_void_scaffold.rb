# frozen_string_literal: true

require "pbt"
require "rspec"
require_relative "authorization_expiry_void_impl"
require_relative "authorization_expiry_void_pbt_config" if File.exist?(File.expand_path("authorization_expiry_void_pbt_config.rb", __dir__))

if File.exist?(File.expand_path("authorization_expiry_void_pbt_config.rb", __dir__)) && !defined?(::AuthorizationExpiryVoidPbtConfig)
  raise "Expected AuthorizationExpiryVoidPbtConfig to be defined in authorization_expiry_void_pbt_config.rb"
end

RSpec.describe "authorization_expiry_void (stateful scaffold)" do
  # Regeneration-safe customization:
  # - edit authorization_expiry_void_pbt_config.rb for SUT wiring and durable API mapping
  # - edit authorization_expiry_void_impl.rb for implementation behavior
  # - edit this scaffold only for one-off refinements when needed

  module AuthorizationExpiryVoidPbtSupport
    module_function

    def config
      defined?(::AuthorizationExpiryVoidPbtConfig) ? ::AuthorizationExpiryVoidPbtConfig : {}
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

  it "wires a stateful PBT scaffold (customize before enabling)" do
    unless ENV["ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD"] == "1"
      skip "Set ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 after customizing the generated scaffold"
    end

    Pbt.assert(worker: :none, num_runs: 5, seed: 1) do
      Pbt.stateful(
        model: AuthorizationExpiryVoidModel.new,
        sut: -> { AuthorizationExpiryVoidPbtSupport.sut_factory(-> { AuthorizationExpiryVoidImpl.new }).call },
        max_steps: 20
      )
    end
  end

  class AuthorizationExpiryVoidModel
    def initialize
      @commands = [
        AuthorizeCommand.new,
        VoidCommand.new,
        ExpireCommand.new
      ]
    end

    def initial_state
      default_state = { available: 0, held: 0 } # TODO: replace with a domain-specific structured model state
      AuthorizationExpiryVoidPbtSupport.initial_state(default_state)
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

    def arguments(state)
      Pbt.integer(min: 1, max: state[:available])
    end

    def applicable?(state, args)
      override = AuthorizationExpiryVoidPbtSupport.applicable_override(name)
      return AuthorizationExpiryVoidPbtSupport.call_applicable_override(override, state, args) if override
      return true if AuthorizationExpiryVoidPbtSupport.guard_failure_policy(name)
      guard_satisfied?(state, args)
    end

    def guard_satisfied?(state, args = nil)
      delta = AuthorizationExpiryVoidPbtSupport.scalar_model_arg(name, args)
      current_value = state[:available]
      delta.is_a?(Numeric) && delta.positive? && delta <= current_value
    end

    def next_state(state, args)
      override = AuthorizationExpiryVoidPbtSupport.next_state_override(name)
      return AuthorizationExpiryVoidPbtSupport.call_next_state_override(override, state, args) if override
      return state if AuthorizationExpiryVoidPbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      delta = AuthorizationExpiryVoidPbtSupport.scalar_model_arg(name, args)
      state.merge(available: state[:available] - delta, held: state[:held] + delta)
    end

    def run!(sut, args)
      AuthorizationExpiryVoidPbtSupport.before_run_hook&.call(sut)
      payload = AuthorizationExpiryVoidPbtSupport.adapt_args(name, args)
      method_name = AuthorizationExpiryVoidPbtSupport.resolve_method_name(name, :authorize)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(AuthorizationExpiryVoidPbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = AuthorizationExpiryVoidPbtSupport.adapt_result(name, result)
      AuthorizationExpiryVoidPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#a.available>=amount implies#a'.available=sub[#a.available,amount]and#a'.held=add[#a.held,amount]"
      # Analyzer hints: state_field="available", size_delta=1, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:decrement_like, command_confidence=:medium, guard_kind=:arg_within_state, guard_field="available", rhs_source_kind=:arg, state_update_shape=:decrement
      # Related Alloy property predicates: Void, Expire, NonNegativeAvailable
      # Related pattern hints: size
      # Derived verify hints: check_size_semantics, check_non_negative_scalar_state, check_guard_failure_semantics
      policy = AuthorizationExpiryVoidPbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if AuthorizationExpiryVoidPbtSupport.call_verify_override(
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
        observed = AuthorizationExpiryVoidPbtSupport.observed_state(sut)
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
      # Inferred state target: Authorization#available
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from related assertions/facts: keep non-negative scalar invariants aligned with the model state
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      delta = AuthorizationExpiryVoidPbtSupport.scalar_model_arg(name, args)
      before_available = before_state[:available]
      after_available = after_state[:available]
      raise "Expected sufficient scalar state before decrement" unless delta <= before_state[:available]
      raise "Expected decremented value for Authorization#available" unless after_available == before_available - delta
      raise "Expected non-negative value for Authorization#available" unless after_available >= 0
      before_held = before_state[:held]
      after_held = after_state[:held]
      raise "Expected incremented value for Authorization#held" unless after_held == before_held + delta
      raise "Expected non-negative value for Authorization#held" unless after_held >= 0
      raise "Expected total scalar value to stay the same" unless after_available + after_held == before_available + before_held
      [sut, args] && nil
    end
  end

  class VoidCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :void
    end

    def arguments(state)
      Pbt.integer(min: 1, max: state[:held])
    end

    def applicable?(state, args)
      override = AuthorizationExpiryVoidPbtSupport.applicable_override(name)
      return AuthorizationExpiryVoidPbtSupport.call_applicable_override(override, state, args) if override
      return true if AuthorizationExpiryVoidPbtSupport.guard_failure_policy(name)
      guard_satisfied?(state, args)
    end

    def guard_satisfied?(state, args = nil)
      delta = AuthorizationExpiryVoidPbtSupport.scalar_model_arg(name, args)
      current_value = state[:held]
      delta.is_a?(Numeric) && delta.positive? && delta <= current_value
    end

    def next_state(state, args)
      override = AuthorizationExpiryVoidPbtSupport.next_state_override(name)
      return AuthorizationExpiryVoidPbtSupport.call_next_state_override(override, state, args) if override
      return state if AuthorizationExpiryVoidPbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      delta = AuthorizationExpiryVoidPbtSupport.scalar_model_arg(name, args)
      state.merge(available: state[:available] + delta, held: state[:held] - delta)
    end

    def run!(sut, args)
      AuthorizationExpiryVoidPbtSupport.before_run_hook&.call(sut)
      payload = AuthorizationExpiryVoidPbtSupport.adapt_args(name, args)
      method_name = AuthorizationExpiryVoidPbtSupport.resolve_method_name(name, :void)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(AuthorizationExpiryVoidPbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = AuthorizationExpiryVoidPbtSupport.adapt_result(name, result)
      AuthorizationExpiryVoidPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#a.held>=amount implies#a'.available=add[#a.available,amount]and#a'.held=sub[#a.held,amount]"
      # Analyzer hints: state_field="held", size_delta=1, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:decrement_like, command_confidence=:medium, guard_kind=:arg_within_state, guard_field="held", rhs_source_kind=:arg, state_update_shape=:decrement
      # Related Alloy property predicates: Authorize, Expire, NonNegativeHeld
      # Related pattern hints: size
      # Derived verify hints: check_size_semantics, check_non_negative_scalar_state, check_guard_failure_semantics
      policy = AuthorizationExpiryVoidPbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if AuthorizationExpiryVoidPbtSupport.call_verify_override(
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
        observed = AuthorizationExpiryVoidPbtSupport.observed_state(sut)
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
      # Inferred state target: Authorization#held
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from related assertions/facts: keep non-negative scalar invariants aligned with the model state
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      delta = AuthorizationExpiryVoidPbtSupport.scalar_model_arg(name, args)
      before_available = before_state[:available]
      after_available = after_state[:available]
      raise "Expected incremented value for Authorization#available" unless after_available == before_available + delta
      raise "Expected non-negative value for Authorization#available" unless after_available >= 0
      before_held = before_state[:held]
      after_held = after_state[:held]
      raise "Expected sufficient scalar state before decrement" unless delta <= before_state[:held]
      raise "Expected decremented value for Authorization#held" unless after_held == before_held - delta
      raise "Expected non-negative value for Authorization#held" unless after_held >= 0
      raise "Expected total scalar value to stay the same" unless after_available + after_held == before_available + before_held
      [sut, args] && nil
    end
  end

  class ExpireCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :expire
    end

    def arguments(state)
      Pbt.integer(min: 1, max: state[:held])
    end

    def applicable?(state, args)
      override = AuthorizationExpiryVoidPbtSupport.applicable_override(name)
      return AuthorizationExpiryVoidPbtSupport.call_applicable_override(override, state, args) if override
      return true if AuthorizationExpiryVoidPbtSupport.guard_failure_policy(name)
      guard_satisfied?(state, args)
    end

    def guard_satisfied?(state, args = nil)
      delta = AuthorizationExpiryVoidPbtSupport.scalar_model_arg(name, args)
      current_value = state[:held]
      delta.is_a?(Numeric) && delta.positive? && delta <= current_value
    end

    def next_state(state, args)
      override = AuthorizationExpiryVoidPbtSupport.next_state_override(name)
      return AuthorizationExpiryVoidPbtSupport.call_next_state_override(override, state, args) if override
      return state if AuthorizationExpiryVoidPbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      delta = AuthorizationExpiryVoidPbtSupport.scalar_model_arg(name, args)
      state.merge(available: state[:available] + delta, held: state[:held] - delta)
    end

    def run!(sut, args)
      AuthorizationExpiryVoidPbtSupport.before_run_hook&.call(sut)
      payload = AuthorizationExpiryVoidPbtSupport.adapt_args(name, args)
      method_name = AuthorizationExpiryVoidPbtSupport.resolve_method_name(name, :expire)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(AuthorizationExpiryVoidPbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = AuthorizationExpiryVoidPbtSupport.adapt_result(name, result)
      AuthorizationExpiryVoidPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#a.held>=amount implies#a'.available=add[#a.available,amount]and#a'.held=sub[#a.held,amount]"
      # Analyzer hints: state_field="held", size_delta=1, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:decrement_like, command_confidence=:medium, guard_kind=:arg_within_state, guard_field="held", rhs_source_kind=:arg, state_update_shape=:decrement
      # Related Alloy property predicates: Authorize, Void, NonNegativeHeld
      # Related pattern hints: size
      # Derived verify hints: check_size_semantics, check_non_negative_scalar_state, check_guard_failure_semantics
      policy = AuthorizationExpiryVoidPbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if AuthorizationExpiryVoidPbtSupport.call_verify_override(
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
        observed = AuthorizationExpiryVoidPbtSupport.observed_state(sut)
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
      # Inferred state target: Authorization#held
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from related assertions/facts: keep non-negative scalar invariants aligned with the model state
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      delta = AuthorizationExpiryVoidPbtSupport.scalar_model_arg(name, args)
      before_available = before_state[:available]
      after_available = after_state[:available]
      raise "Expected incremented value for Authorization#available" unless after_available == before_available + delta
      raise "Expected non-negative value for Authorization#available" unless after_available >= 0
      before_held = before_state[:held]
      after_held = after_state[:held]
      raise "Expected sufficient scalar state before decrement" unless delta <= before_state[:held]
      raise "Expected decremented value for Authorization#held" unless after_held == before_held - delta
      raise "Expected non-negative value for Authorization#held" unless after_held >= 0
      raise "Expected total scalar value to stay the same" unless after_available + after_held == before_available + before_held
      [sut, args] && nil
    end
  end

end