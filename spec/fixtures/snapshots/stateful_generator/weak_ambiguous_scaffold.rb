# frozen_string_literal: true

require "pbt"
require "rspec"
require_relative "weak_impl"
require_relative "weak_pbt_config" if File.exist?(File.expand_path("weak_pbt_config.rb", __dir__))

if File.exist?(File.expand_path("weak_pbt_config.rb", __dir__)) && !defined?(::WeakPbtConfig)
  raise "Expected WeakPbtConfig to be defined in weak_pbt_config.rb"
end

RSpec.describe "weak (stateful scaffold)" do
  # Regeneration-safe customization:
  # - edit weak_pbt_config.rb for SUT wiring and durable API mapping
  # - edit weak_impl.rb for implementation behavior
  # - edit this scaffold only for one-off refinements when needed

  module WeakPbtSupport
    module_function

    def config
      defined?(::WeakPbtConfig) ? ::WeakPbtConfig : {}
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
        model: WeakModel.new,
        sut: -> { WeakPbtSupport.sut_factory(-> { WeakImpl.new }).call },
        max_steps: 20
      )
    end
  end

  class WeakModel
    def initialize
      @commands = [
        GeneratedCommand.new
      ]
    end

    def initial_state
      [] # TODO: replace with a domain-specific model state
    end

    def commands(_state)
      @commands
    end
  end

  class GeneratedCommand
    def name
      :generated_command
    end

    def arguments
      Pbt.nil
    end

    def applicable?(_state)
      true
    end

    def next_state(state, _args)
      state
    end

    def run!(_sut, _args)
      nil
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: no command-like predicates were detected; replace this placeholder
      nil
    end
  end

end