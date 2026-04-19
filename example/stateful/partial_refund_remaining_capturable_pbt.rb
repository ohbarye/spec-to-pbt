# frozen_string_literal: true

require_relative "pbt_local"
require "rspec"
require_relative "partial_refund_remaining_capturable_impl"
require_relative "partial_refund_remaining_capturable_pbt_config" if File.exist?(File.expand_path("partial_refund_remaining_capturable_pbt_config.rb", __dir__))

if File.exist?(File.expand_path("partial_refund_remaining_capturable_pbt_config.rb", __dir__)) && !defined?(::PartialRefundRemainingCapturablePbtConfig)
  raise "Expected PartialRefundRemainingCapturablePbtConfig to be defined in partial_refund_remaining_capturable_pbt_config.rb"
end

RSpec.describe "partial_refund_remaining_capturable (stateful scaffold)" do
  # Regeneration-safe customization:
  # - edit partial_refund_remaining_capturable_pbt_config.rb for SUT wiring and durable API mapping
  # - edit partial_refund_remaining_capturable_impl.rb for implementation behavior
  # - edit this scaffold only for one-off refinements when needed

  module PartialRefundRemainingCapturablePbtSupport
    module_function

    def config
      defined?(::PartialRefundRemainingCapturablePbtConfig) ? ::PartialRefundRemainingCapturablePbtConfig : {}
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
        model: PartialRefundRemainingCapturableModel.new,
        sut: -> { PartialRefundRemainingCapturablePbtSupport.sut_factory(-> { PartialRefundRemainingCapturableImpl.new }).call },
        max_steps: 20
      )
    end
  end

  class PartialRefundRemainingCapturableModel
    def initialize
      @commands = [
        CaptureCommand.new,
        RefundCommand.new
      ]
    end

    def initial_state
      default_state = { authorized: 0, captured: 0, refunded: 0 } # TODO: replace with a domain-specific structured model state
      PartialRefundRemainingCapturablePbtSupport.initial_state(default_state)
    end

    def commands(_state)
      @commands
    end
  end

  class CaptureCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :capture
    end

    def arguments(state)
      Pbt.integer(min: 1, max: state[:authorized])
    end

    def applicable?(state, args)
      override = PartialRefundRemainingCapturablePbtSupport.applicable_override(name)
      return PartialRefundRemainingCapturablePbtSupport.call_applicable_override(override, state, args) if override
      return true if PartialRefundRemainingCapturablePbtSupport.guard_failure_policy(name)
      guard_satisfied?(state, args)
    end

    def guard_satisfied?(state, args = nil)
      delta = PartialRefundRemainingCapturablePbtSupport.scalar_model_arg(name, args)
      current_value = state[:authorized]
      delta.is_a?(Numeric) && delta.positive? && delta <= current_value
    end

    def next_state(state, args)
      override = PartialRefundRemainingCapturablePbtSupport.next_state_override(name)
      return PartialRefundRemainingCapturablePbtSupport.call_next_state_override(override, state, args) if override
      return state if PartialRefundRemainingCapturablePbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      delta = PartialRefundRemainingCapturablePbtSupport.scalar_model_arg(name, args)
      state.merge(authorized: state[:authorized] - delta, captured: state[:captured] + delta)
    end

    def run!(sut, args)
      PartialRefundRemainingCapturablePbtSupport.before_run_hook&.call(sut)
      payload = PartialRefundRemainingCapturablePbtSupport.adapt_args(name, args)
      method_name = PartialRefundRemainingCapturablePbtSupport.resolve_method_name(name, :capture)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(PartialRefundRemainingCapturablePbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = PartialRefundRemainingCapturablePbtSupport.adapt_result(name, result)
      PartialRefundRemainingCapturablePbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#p.authorized>=amount implies#p'.authorized=sub[#p.authorized,amount]and#p'.captured=add[#p.captured,amount]"
      # Analyzer hints: state_field="authorized", size_delta=1, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:decrement_like, command_confidence=:medium, guard_kind=:arg_within_state, guard_field="authorized", rhs_source_kind=:arg, state_update_shape=:decrement
      # Related Alloy property predicates: Refund, NonNegativeAuthorized
      # Related pattern hints: size
      # Derived verify hints: check_size_semantics, check_non_negative_scalar_state, check_guard_failure_semantics
      policy = PartialRefundRemainingCapturablePbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if PartialRefundRemainingCapturablePbtSupport.call_verify_override(
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
        observed = PartialRefundRemainingCapturablePbtSupport.observed_state(sut)
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
      # Inferred state target: Payment#authorized
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from related assertions/facts: keep non-negative scalar invariants aligned with the model state
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      delta = PartialRefundRemainingCapturablePbtSupport.scalar_model_arg(name, args)
      before_authorized = before_state[:authorized]
      after_authorized = after_state[:authorized]
      raise "Expected sufficient scalar state before decrement" unless delta <= before_state[:authorized]
      raise "Expected decremented value for Payment#authorized" unless after_authorized == before_authorized - delta
      raise "Expected non-negative value for Payment#authorized" unless after_authorized >= 0
      before_captured = before_state[:captured]
      after_captured = after_state[:captured]
      raise "Expected incremented value for Payment#captured" unless after_captured == before_captured + delta
      raise "Expected non-negative value for Payment#captured" unless after_captured >= 0
      raise "Expected total scalar value to stay the same" unless after_authorized + after_captured == before_authorized + before_captured
      [sut, args] && nil
    end
  end

  class RefundCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :refund
    end

    def arguments(state)
      Pbt.integer(min: 1, max: state[:captured])
    end

    def applicable?(state, args)
      override = PartialRefundRemainingCapturablePbtSupport.applicable_override(name)
      return PartialRefundRemainingCapturablePbtSupport.call_applicable_override(override, state, args) if override
      return true if PartialRefundRemainingCapturablePbtSupport.guard_failure_policy(name)
      guard_satisfied?(state, args)
    end

    def guard_satisfied?(state, args = nil)
      delta = PartialRefundRemainingCapturablePbtSupport.scalar_model_arg(name, args)
      current_value = state[:captured]
      delta.is_a?(Numeric) && delta.positive? && delta <= current_value
    end

    def next_state(state, args)
      override = PartialRefundRemainingCapturablePbtSupport.next_state_override(name)
      return PartialRefundRemainingCapturablePbtSupport.call_next_state_override(override, state, args) if override
      return state if PartialRefundRemainingCapturablePbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      delta = PartialRefundRemainingCapturablePbtSupport.scalar_model_arg(name, args)
      state.merge(captured: state[:captured] - delta, refunded: state[:refunded] + delta)
    end

    def run!(sut, args)
      PartialRefundRemainingCapturablePbtSupport.before_run_hook&.call(sut)
      payload = PartialRefundRemainingCapturablePbtSupport.adapt_args(name, args)
      method_name = PartialRefundRemainingCapturablePbtSupport.resolve_method_name(name, :refund)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(PartialRefundRemainingCapturablePbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = PartialRefundRemainingCapturablePbtSupport.adapt_result(name, result)
      PartialRefundRemainingCapturablePbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#p.captured>=amount implies#p'.captured=sub[#p.captured,amount]and#p'.refunded=add[#p.refunded,amount]"
      # Analyzer hints: state_field="captured", size_delta=1, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:decrement_like, command_confidence=:medium, guard_kind=:arg_within_state, guard_field="captured", rhs_source_kind=:arg, state_update_shape=:decrement
      # Related Alloy property predicates: Capture, NonNegativeCaptured
      # Related pattern hints: size
      # Derived verify hints: check_size_semantics, check_non_negative_scalar_state, check_guard_failure_semantics
      policy = PartialRefundRemainingCapturablePbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if PartialRefundRemainingCapturablePbtSupport.call_verify_override(
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
        observed = PartialRefundRemainingCapturablePbtSupport.observed_state(sut)
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
      # Inferred state target: Payment#captured
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from related assertions/facts: keep non-negative scalar invariants aligned with the model state
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      delta = PartialRefundRemainingCapturablePbtSupport.scalar_model_arg(name, args)
      before_captured = before_state[:captured]
      after_captured = after_state[:captured]
      raise "Expected sufficient scalar state before decrement" unless delta <= before_state[:captured]
      raise "Expected decremented value for Payment#captured" unless after_captured == before_captured - delta
      raise "Expected non-negative value for Payment#captured" unless after_captured >= 0
      before_refunded = before_state[:refunded]
      after_refunded = after_state[:refunded]
      raise "Expected incremented value for Payment#refunded" unless after_refunded == before_refunded + delta
      raise "Expected non-negative value for Payment#refunded" unless after_refunded >= 0
      raise "Expected total scalar value to stay the same" unless after_captured + after_refunded == before_captured + before_refunded
      [sut, args] && nil
    end
  end

end