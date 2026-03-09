# frozen_string_literal: true

require "pbt"
require "rspec"
require_relative "connection_pool_impl"
require_relative "connection_pool_pbt_config" if File.exist?(File.expand_path("connection_pool_pbt_config.rb", __dir__))

if File.exist?(File.expand_path("connection_pool_pbt_config.rb", __dir__)) && !defined?(::ConnectionPoolPbtConfig)
  raise "Expected ConnectionPoolPbtConfig to be defined in connection_pool_pbt_config.rb"
end

RSpec.describe "connection_pool (stateful scaffold)" do
  # Regeneration-safe customization:
  # - edit connection_pool_pbt_config.rb for SUT wiring and durable API mapping
  # - edit connection_pool_impl.rb for implementation behavior
  # - edit this scaffold only for one-off refinements when needed

  module ConnectionPoolPbtSupport
    module_function

    def config
      defined?(::ConnectionPoolPbtConfig) ? ::ConnectionPoolPbtConfig : {}
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
        model: ConnectionPoolModel.new,
        sut: -> { ConnectionPoolPbtSupport.sut_factory(-> { ConnectionPoolImpl.new }).call },
        max_steps: 20
      )
    end
  end

  class ConnectionPoolModel
    def initialize
      @commands = [
        CheckoutCommand.new,
        CheckinCommand.new
      ]
    end

    def initial_state
      default_state = { available: 0, checked_out: 0, capacity: 3 } # TODO: replace with a domain-specific structured model state
      ConnectionPoolPbtSupport.initial_state(default_state)
    end

    def commands(_state)
      @commands
    end
  end

  class CheckoutCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :checkout
    end

    def arguments
      Pbt.nil
    end

    def applicable?(state)
      override = ConnectionPoolPbtSupport.applicable_override(name)
      return ConnectionPoolPbtSupport.call_applicable_override(override, state, nil) if override
      return true if ConnectionPoolPbtSupport.guard_failure_policy(name)
      guard_satisfied?(state)
    end

    def guard_satisfied?(state, _args = nil)
      state[:available] > 0 # inferred scalar precondition for checkout
    end

    def next_state(state, args)
      override = ConnectionPoolPbtSupport.next_state_override(name)
      return ConnectionPoolPbtSupport.call_next_state_override(override, state, args) if override
      return state if ConnectionPoolPbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      state.merge(available: state[:available] - 1, checked_out: state[:checked_out] + 1)
    end

    def run!(sut, args)
      ConnectionPoolPbtSupport.before_run_hook&.call(sut)
      payload = ConnectionPoolPbtSupport.adapt_args(name, args)
      method_name = ConnectionPoolPbtSupport.resolve_method_name(name, :checkout)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless ConnectionPoolPbtSupport.guard_failure_policy(name) == :raise
        error
      end
      adapted_result = ConnectionPoolPbtSupport.adapt_result(name, result)
      ConnectionPoolPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#p.available>0 implies#p'.available=sub[#p.available,1]and#p'.checked_out=add[#p.checked_out,1]"
      # Analyzer hints: state_field="available", size_delta=1, transition_kind=nil, requires_non_empty_state=true, scalar_update_kind=:decrement_like, command_confidence=:medium, guard_kind=:non_empty, rhs_source_kind=:unknown, state_update_shape=:decrement
      # Related Alloy property predicates: Checkin, CapacityPreserved
      # Related pattern hints: size, invariant
      # Derived verify hints: respect_non_empty_guard, respect_capacity_guard, check_size_semantics, check_guard_failure_semantics
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if ConnectionPoolPbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut
      )
      policy = ConnectionPoolPbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      raise result if result.is_a?(StandardError) && !guard_failed
      if guard_failed
        observed = ConnectionPoolPbtSupport.observed_state(sut)
        case policy
        when :no_op
          raise "Expected unchanged model state on guard failure" unless after_state == before_state
          raise "Expected unchanged observed state on guard failure" if !observed.nil? && observed != after_state
        when :raise
          raise "Expected guard failure to surface as an exception" unless result.is_a?(StandardError)
          raise "Expected unchanged model state on guard failure" unless after_state == before_state
          raise "Expected unchanged observed state on guard failure" if !observed.nil? && observed != after_state
        else
          raise "Unsupported guard_failure_policy: #{policy.inspect}"
        end
        return nil
      end
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Pool#available
      # Derived from related assertions/facts: respect the non-empty guard before removal-style checks
      # Derived from related assertions/facts: respect capacity/fullness guards before append-style checks
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      before_available = before_state[:available]
      after_available = after_state[:available]
      raise "Expected decremented value for Pool#available" unless after_available == before_available - 1
      before_checked_out = before_state[:checked_out]
      after_checked_out = after_state[:checked_out]
      raise "Expected incremented value for Pool#checked_out" unless after_checked_out == before_checked_out + 1
      raise "Expected total scalar value to stay the same" unless after_available + after_checked_out == before_available + before_checked_out
      [sut, args] && nil
    end
  end

  class CheckinCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :checkin
    end

    def arguments
      Pbt.nil
    end

    def applicable?(state)
      override = ConnectionPoolPbtSupport.applicable_override(name)
      return ConnectionPoolPbtSupport.call_applicable_override(override, state, nil) if override
      return true if ConnectionPoolPbtSupport.guard_failure_policy(name)
      guard_satisfied?(state)
    end

    def guard_satisfied?(state, _args = nil)
      state[:checked_out] > 0 # inferred scalar precondition for checkin
    end

    def next_state(state, args)
      override = ConnectionPoolPbtSupport.next_state_override(name)
      return ConnectionPoolPbtSupport.call_next_state_override(override, state, args) if override
      return state if ConnectionPoolPbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      state.merge(available: state[:available] + 1, checked_out: state[:checked_out] - 1)
    end

    def run!(sut, args)
      ConnectionPoolPbtSupport.before_run_hook&.call(sut)
      payload = ConnectionPoolPbtSupport.adapt_args(name, args)
      method_name = ConnectionPoolPbtSupport.resolve_method_name(name, :checkin)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless ConnectionPoolPbtSupport.guard_failure_policy(name) == :raise
        error
      end
      adapted_result = ConnectionPoolPbtSupport.adapt_result(name, result)
      ConnectionPoolPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#p.checked_out>0 implies#p'.available=add[#p.available,1]and#p'.checked_out=sub[#p.checked_out,1]"
      # Analyzer hints: state_field="checked_out", size_delta=1, transition_kind=nil, requires_non_empty_state=true, scalar_update_kind=:decrement_like, command_confidence=:medium, guard_kind=:non_empty, rhs_source_kind=:unknown, state_update_shape=:decrement
      # Related Alloy property predicates: Checkout
      # Related pattern hints: size
      # Derived verify hints: respect_non_empty_guard, check_size_semantics, check_guard_failure_semantics
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if ConnectionPoolPbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut
      )
      policy = ConnectionPoolPbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      raise result if result.is_a?(StandardError) && !guard_failed
      if guard_failed
        observed = ConnectionPoolPbtSupport.observed_state(sut)
        case policy
        when :no_op
          raise "Expected unchanged model state on guard failure" unless after_state == before_state
          raise "Expected unchanged observed state on guard failure" if !observed.nil? && observed != after_state
        when :raise
          raise "Expected guard failure to surface as an exception" unless result.is_a?(StandardError)
          raise "Expected unchanged model state on guard failure" unless after_state == before_state
          raise "Expected unchanged observed state on guard failure" if !observed.nil? && observed != after_state
        else
          raise "Unsupported guard_failure_policy: #{policy.inspect}"
        end
        return nil
      end
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Pool#checked_out
      # Derived from related assertions/facts: respect the non-empty guard before removal-style checks
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      before_available = before_state[:available]
      after_available = after_state[:available]
      raise "Expected incremented value for Pool#available" unless after_available == before_available + 1
      before_checked_out = before_state[:checked_out]
      after_checked_out = after_state[:checked_out]
      raise "Expected decremented value for Pool#checked_out" unless after_checked_out == before_checked_out - 1
      raise "Expected total scalar value to stay the same" unless after_available + after_checked_out == before_available + before_checked_out
      [sut, args] && nil
    end
  end

end