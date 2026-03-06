# frozen_string_literal: true

require "pbt"
require "rspec"
require_relative "sort_impl"
require_relative "sort_pbt_config" if File.exist?(File.expand_path("sort_pbt_config.rb", __dir__))

if File.exist?(File.expand_path("sort_pbt_config.rb", __dir__)) && !defined?(::SortPbtConfig)
  raise "Expected SortPbtConfig to be defined in sort_pbt_config.rb"
end

RSpec.describe "sort (stateful scaffold)" do
  # Regeneration-safe customization:
  # - edit sort_pbt_config.rb for SUT wiring and durable API mapping
  # - edit sort_impl.rb for implementation behavior
  # - edit this scaffold only for one-off refinements when needed

  module SortPbtSupport
    module_function

    def config
      defined?(::SortPbtConfig) ? ::SortPbtConfig : {}
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
        model: SortModel.new,
        sut: -> { SortPbtSupport.sut_factory(-> { SortImpl.new }).call },
        max_steps: 20
      )
    end
  end

  class SortModel
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