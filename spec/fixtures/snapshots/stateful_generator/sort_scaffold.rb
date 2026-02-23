# frozen_string_literal: true

require "pbt"
require "rspec"
require_relative "sort_impl"

RSpec.describe "sort (stateful scaffold)" do
  it "wires a stateful PBT scaffold (customize before enabling)" do
    unless ENV["ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD"] == "1"
      skip "Set ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 after customizing the generated scaffold"
    end

    Pbt.assert(worker: :none, num_runs: 5, seed: 1) do
      Pbt.stateful(
        model: SortModel.new,
        sut: -> { SortImpl.new },
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