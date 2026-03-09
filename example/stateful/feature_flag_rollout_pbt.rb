# frozen_string_literal: true

require_relative "pbt_local"
require "rspec"
require_relative "feature_flag_rollout_impl"
require_relative "feature_flag_rollout_pbt_config" if File.exist?(File.expand_path("feature_flag_rollout_pbt_config.rb", __dir__))

if File.exist?(File.expand_path("feature_flag_rollout_pbt_config.rb", __dir__)) && !defined?(::FeatureFlagRolloutPbtConfig)
  raise "Expected FeatureFlagRolloutPbtConfig to be defined in feature_flag_rollout_pbt_config.rb"
end

RSpec.describe "feature_flag_rollout (stateful scaffold)" do
  # Regeneration-safe customization:
  # - edit feature_flag_rollout_pbt_config.rb for SUT wiring and durable API mapping
  # - edit feature_flag_rollout_impl.rb for implementation behavior
  # - edit this scaffold only for one-off refinements when needed

  module FeatureFlagRolloutPbtSupport
    module_function

    def config
      defined?(::FeatureFlagRolloutPbtConfig) ? ::FeatureFlagRolloutPbtConfig : {}
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
        model: FeatureFlagRolloutModel.new,
        sut: -> { FeatureFlagRolloutPbtSupport.sut_factory(-> { FeatureFlagRolloutImpl.new }).call },
        max_steps: 20
      )
    end
  end

  class FeatureFlagRolloutModel
    def initialize
      @commands = [
        EnableCommand.new,
        DisableCommand.new,
        RolloutCommand.new
      ]
    end

    def initial_state
      default_state = { rollout: 0, max_rollout: 3 } # TODO: replace with a domain-specific structured model state
      FeatureFlagRolloutPbtSupport.initial_state(default_state)
    end

    def commands(_state)
      @commands
    end
  end

  class EnableCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :enable
    end

    def arguments
      Pbt.nil
    end

    def applicable?(state)
      override = FeatureFlagRolloutPbtSupport.applicable_override(name)
      return FeatureFlagRolloutPbtSupport.call_applicable_override(override, state, nil) if override
      true
    end

    def next_state(state, args)
      override = FeatureFlagRolloutPbtSupport.next_state_override(name)
      return FeatureFlagRolloutPbtSupport.call_next_state_override(override, state, args) if override
      state.merge(rollout: state[:max_rollout])
    end

    def run!(sut, args)
      FeatureFlagRolloutPbtSupport.before_run_hook&.call(sut)
      payload = FeatureFlagRolloutPbtSupport.adapt_args(name, args)
      method_name = FeatureFlagRolloutPbtSupport.resolve_method_name(name, :enable)
      result = if payload.nil?
        sut.public_send(method_name)
      elsif payload.is_a?(Array)
        sut.public_send(method_name, *payload)
      else
        sut.public_send(method_name, payload)
      end
      adapted_result = FeatureFlagRolloutPbtSupport.adapt_result(name, result)
      FeatureFlagRolloutPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#f'.rollout=#f.max_rollout"
      # Analyzer hints: state_field="rollout", size_delta=0, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:replace_like, command_confidence=:medium, guard_kind=:none, rhs_source_kind=:state_field, state_update_shape=:replace_value
      # Related Alloy property predicates: Disable, Rollout, RolloutBounded
      # Related pattern hints: size
      # Derived verify hints: respect_capacity_guard, check_size_semantics, check_non_negative_scalar_state
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if FeatureFlagRolloutPbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut
      )
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Flag#rollout
      # Derived from related assertions/facts: respect capacity/fullness guards before append-style checks
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from related assertions/facts: keep non-negative scalar invariants aligned with the model state
      expected = before_state[:max_rollout]
      raise "Expected replaced value for Flag#rollout" unless after_state[:rollout] == expected
      raise "Expected non-negative value for Flag#rollout" unless after_state[:rollout] >= 0
      [sut, args] && nil
    end
  end

  class DisableCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :disable
    end

    def arguments
      Pbt.nil
    end

    def applicable?(state)
      override = FeatureFlagRolloutPbtSupport.applicable_override(name)
      return FeatureFlagRolloutPbtSupport.call_applicable_override(override, state, nil) if override
      true
    end

    def next_state(state, args)
      override = FeatureFlagRolloutPbtSupport.next_state_override(name)
      return FeatureFlagRolloutPbtSupport.call_next_state_override(override, state, args) if override
      state # TODO: replace Flag#rollout using args/result
    end

    def run!(sut, args)
      FeatureFlagRolloutPbtSupport.before_run_hook&.call(sut)
      payload = FeatureFlagRolloutPbtSupport.adapt_args(name, args)
      method_name = FeatureFlagRolloutPbtSupport.resolve_method_name(name, :disable)
      result = if payload.nil?
        sut.public_send(method_name)
      elsif payload.is_a?(Array)
        sut.public_send(method_name, *payload)
      else
        sut.public_send(method_name, payload)
      end
      adapted_result = FeatureFlagRolloutPbtSupport.adapt_result(name, result)
      FeatureFlagRolloutPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#f'.rollout=0"
      # Analyzer hints: state_field="rollout", size_delta=nil, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:replace_like, command_confidence=:medium, guard_kind=:none, rhs_source_kind=:unknown, state_update_shape=:replace_value
      # Related Alloy property predicates: Enable, Rollout, RolloutBounded
      # Related pattern hints: size
      # Derived verify hints: respect_capacity_guard, check_size_semantics, check_non_negative_scalar_state
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if FeatureFlagRolloutPbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut
      )
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Flag#rollout
      # Derived from related assertions/facts: respect capacity/fullness guards before append-style checks
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from related assertions/facts: keep non-negative scalar invariants aligned with the model state
      # TODO: verify replaced value for Flag#rollout
      # Example shape: compare the inferred target against args/result
      raise "Expected non-negative value for Flag#rollout" unless after_state[:rollout] >= 0
      [sut, args] && nil
    end
  end

  class RolloutCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :rollout
    end

    def arguments
      Pbt.integer
    end

    def applicable?(state)
      override = FeatureFlagRolloutPbtSupport.applicable_override(name)
      return FeatureFlagRolloutPbtSupport.call_applicable_override(override, state, nil) if override
      true
    end

    def next_state(state, args)
      override = FeatureFlagRolloutPbtSupport.next_state_override(name)
      return FeatureFlagRolloutPbtSupport.call_next_state_override(override, state, args) if override
      state.merge(rollout: FeatureFlagRolloutPbtSupport.scalar_model_arg(name, args))
    end

    def run!(sut, args)
      FeatureFlagRolloutPbtSupport.before_run_hook&.call(sut)
      payload = FeatureFlagRolloutPbtSupport.adapt_args(name, args)
      method_name = FeatureFlagRolloutPbtSupport.resolve_method_name(name, :rollout)
      result = if payload.nil?
        sut.public_send(method_name)
      elsif payload.is_a?(Array)
        sut.public_send(method_name, *payload)
      else
        sut.public_send(method_name, payload)
      end
      adapted_result = FeatureFlagRolloutPbtSupport.adapt_result(name, result)
      FeatureFlagRolloutPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#f.max_rollout>=percent implies#f'.rollout=#percent"
      # Analyzer hints: state_field="rollout", size_delta=0, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:replace_like, command_confidence=:medium, guard_kind=:none, rhs_source_kind=:arg, state_update_shape=:replace_with_arg
      # Related Alloy property predicates: Enable, Disable, RolloutBounded
      # Related pattern hints: size
      # Derived verify hints: respect_capacity_guard, check_size_semantics, check_non_negative_scalar_state
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if FeatureFlagRolloutPbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut
      )
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Flag#rollout
      # Derived from related assertions/facts: respect capacity/fullness guards before append-style checks
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from related assertions/facts: keep non-negative scalar invariants aligned with the model state
      expected = FeatureFlagRolloutPbtSupport.scalar_model_arg(name, args)
      raise "Expected replaced value for Flag#rollout" unless after_state[:rollout] == expected
      raise "Expected non-negative value for Flag#rollout" unless after_state[:rollout] >= 0
      [sut, args] && nil
    end
  end

end