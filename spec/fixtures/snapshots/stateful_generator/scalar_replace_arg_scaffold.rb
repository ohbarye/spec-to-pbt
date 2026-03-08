# frozen_string_literal: true

require "pbt"
require "rspec"
require_relative "thermostat_impl"
require_relative "thermostat_pbt_config" if File.exist?(File.expand_path("thermostat_pbt_config.rb", __dir__))

if File.exist?(File.expand_path("thermostat_pbt_config.rb", __dir__)) && !defined?(::ThermostatPbtConfig)
  raise "Expected ThermostatPbtConfig to be defined in thermostat_pbt_config.rb"
end

RSpec.describe "thermostat (stateful scaffold)" do
  # Regeneration-safe customization:
  # - edit thermostat_pbt_config.rb for SUT wiring and durable API mapping
  # - edit thermostat_impl.rb for implementation behavior
  # - edit this scaffold only for one-off refinements when needed

  module ThermostatPbtSupport
    module_function

    def config
      defined?(::ThermostatPbtConfig) ? ::ThermostatPbtConfig : {}
    end

    def sut_factory(default_factory)
      config.fetch(:sut_factory, default_factory)
    end

    def command_config(command_name)
      config.fetch(:command_mappings, {}).fetch(command_name, {})
    end

    def resolve_method_name(command_name, default_method_name)
      command_config(command_name).fetch(:method, default_method_name)
    end

    def adapt_args(command_name, args)
      adapter = command_config(command_name)[:arg_adapter]
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
        model: ThermostatModel.new,
        sut: -> { ThermostatPbtSupport.sut_factory(-> { ThermostatImpl.new }).call },
        max_steps: 20
      )
    end
  end

  class ThermostatModel
    def initialize
      @commands = [
        SetTargetCommand.new
      ]
    end

    def initial_state
      nil # TODO: replace with a domain-specific scalar/model state
    end

    def commands(_state)
      @commands
    end
  end

  class SetTargetCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :set_target
    end

    def arguments
      Pbt.integer
    end

    def applicable?(state)
      override = ThermostatPbtSupport.applicable_override(name)
      return ThermostatPbtSupport.call_applicable_override(override, state, nil) if override
      true
    end

    def next_state(_state, args)
      ThermostatPbtSupport.scalar_model_arg(name, args)
    end

    def run!(sut, args)
      ThermostatPbtSupport.before_run_hook&.call(sut)
      payload = ThermostatPbtSupport.adapt_args(name, args)
      method_name = ThermostatPbtSupport.resolve_method_name(name, :set_target)
      result = if payload.nil?
        sut.public_send(method_name)
      elsif payload.is_a?(Array)
        sut.public_send(method_name, *payload)
      else
        sut.public_send(method_name, payload)
      end
      adapted_result = ThermostatPbtSupport.adapt_result(name, result)
      ThermostatPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#t'.target=next"
      # Analyzer hints: state_field="target", size_delta=nil, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:replace_like, command_confidence=:medium, guard_kind=:none, rhs_source_kind=:arg, state_update_shape=:replace_with_arg
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if ThermostatPbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut
      )
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Thermostat#target
      expected = ThermostatPbtSupport.scalar_model_arg(name, args)
      raise "Expected replaced value for Thermostat#target" unless after_state == expected
      [sut, args] && nil
    end
  end

end