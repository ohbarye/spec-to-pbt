# frozen_string_literal: true

require "pbt"
require "rspec"
require_relative "cache_impl"

RSpec.describe "cache (stateful scaffold)" do
  it "wires a stateful PBT scaffold (customize before enabling)" do
    unless ENV["ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD"] == "1"
      skip "Set ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 after customizing the generated scaffold"
    end

    Pbt.assert(worker: :none, num_runs: 5, seed: 1) do
      Pbt.stateful(
        model: CacheModel.new,
        sut: -> { CacheImpl.new },
        max_steps: 20
      )
    end
  end

  class CacheModel
    def initialize
      @commands = [
        RewriteCommand.new
      ]
    end

    def initial_state
      [] # TODO: replace with a domain-specific collection state
    end

    def commands(_state)
      @commands
    end
  end

  class RewriteCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :rewrite
    end

    def arguments
      Pbt.nil
    end

    def applicable?(_state)
      true
    end

    def next_state(state, _args)
      # Inferred transition target: Cache#entries
      state # TODO: preserve size while refining element/order changes
    end

    def run!(sut, args)
      if args.nil?
        sut.public_send(:rewrite)
      elsif args.is_a?(Array)
        sut.public_send(:rewrite, *args)
      else
        sut.public_send(:rewrite, args)
      end
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#c'.entries=#c.entries"
      # Analyzer hints: state_field="entries", size_delta=0, transition_kind=:size_no_change, requires_non_empty_state=false, scalar_update_kind=nil, command_confidence=:medium, guard_kind=:none, rhs_source_kind=:state_field, state_update_shape=:preserve_size
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      # Inferred collection target: Cache#entries
      raise "Expected size to stay the same" unless after_state.length == before_state.length
      # TODO: add concrete collection checks for Rewrite
      [sut, args] && nil
    end
  end

end