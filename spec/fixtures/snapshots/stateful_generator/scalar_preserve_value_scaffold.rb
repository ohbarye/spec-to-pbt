# frozen_string_literal: true

require "pbt"
require "rspec"
require_relative "box_impl"
require_relative "box_pbt_config" if File.exist?(File.expand_path("box_pbt_config.rb", __dir__))

if File.exist?(File.expand_path("box_pbt_config.rb", __dir__)) && !defined?(::BoxPbtConfig)
  raise "Expected BoxPbtConfig to be defined in box_pbt_config.rb"
end

RSpec.describe "box (stateful scaffold)" do
  # Regeneration-safe customization:
  # - edit box_pbt_config.rb for SUT wiring and durable API mapping
  # - edit box_impl.rb for implementation behavior
  # - edit this scaffold only for one-off refinements when needed

  module BoxPbtSupport
    module_function

    def config
      defined?(::BoxPbtConfig) ? ::BoxPbtConfig : {}
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
        model: BoxModel.new,
        sut: -> { BoxPbtSupport.sut_factory(-> { BoxImpl.new }).call },
        max_steps: 20
      )
    end
  end

  class BoxModel
    def initialize
      @commands = [
        KeepCommand.new
      ]
    end

    def initial_state
      default_state = 0 # TODO: replace with a domain-specific scalar model state
      BoxPbtSupport.initial_state(default_state)
    end

    def commands(_state)
      @commands
    end
  end

  class KeepCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :keep
    end

    def arguments
      Pbt.nil
    end

    def applicable?(state)
      override = BoxPbtSupport.applicable_override(name)
      return BoxPbtSupport.call_applicable_override(override, state, nil) if override
      true
    end

    def next_state(state, args)
      override = BoxPbtSupport.next_state_override(name)
      return BoxPbtSupport.call_next_state_override(override, state, args) if override
      state # TODO: keep Box#value stable unless other domain state changes
    end

    def run!(sut, args)
      BoxPbtSupport.before_run_hook&.call(sut)
      payload = BoxPbtSupport.adapt_args(name, args)
      method_name = BoxPbtSupport.resolve_method_name(name, :keep)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(BoxPbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = BoxPbtSupport.adapt_result(name, result)
      BoxPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#b'.value=#b.value"
      # Analyzer hints: state_field="value", size_delta=0, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:replace_like, command_confidence=:medium, guard_kind=:none, guard_field="value", rhs_source_kind=:state_field, state_update_shape=:preserve_value
      policy = BoxPbtSupport.guard_failure_policy(name)
      guard_failed = false
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if BoxPbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut,
        guard_failed: guard_failed,
        guard_failure_policy: policy
      )
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Box#value
      raise "Expected preserved value for Box#value" unless after_state == before_state
      # Example shape: replace this equality check with a narrower field-level assertion if needed
      [sut, args] && nil
    end
  end

end