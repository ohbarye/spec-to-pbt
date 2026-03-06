# frozen_string_literal: true

require "pbt"
require "rspec"
require_relative "bag_impl"

RSpec.describe "bag (stateful scaffold)" do
  it "wires a stateful PBT scaffold (customize before enabling)" do
    unless ENV["ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD"] == "1"
      skip "Set ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 after customizing the generated scaffold"
    end

    Pbt.assert(worker: :none, num_runs: 5, seed: 1) do
      Pbt.stateful(
        model: BagModel.new,
        sut: -> { BagImpl.new },
        max_steps: 20
      )
    end
  end

  class BagModel
    def initialize
      @commands = [
        DropLastCommand.new
      ]
    end

    def initial_state
      [] # TODO: replace with a domain-specific collection state
    end

    def commands(_state)
      @commands
    end
  end

  class DropLastCommand
    def name
      :drop_last
    end

    def arguments
      Pbt.nil
    end

    def applicable?(state)
      !state.empty? # inferred precondition for drop_last
    end

    def next_state(state, _args)
      # Inferred transition target: Bag#elems
      state[0...-1]
    end

    def run!(sut, args)
      if args.nil?
        sut.public_send(:drop_last)
      elsif args.is_a?(Array)
        sut.public_send(:drop_last, *args)
      else
        sut.public_send(:drop_last, args)
      end
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#b.elems>0 implies#b'.elems=sub[#b.elems,1]"
      # Analyzer hints: state_field="elems", size_delta=-1, transition_kind=:pop, requires_non_empty_state=true, scalar_update_kind=nil, command_confidence=:high, guard_kind=:non_empty, rhs_source_kind=:unknown, state_update_shape=:remove_last
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      # Inferred collection target: Bag#elems
      expected = before_state.last
      raise "Expected popped value to match model" unless result == expected
      raise "Expected size to decrease by 1" unless after_state.length == before_state.length - 1
      [sut, args] && nil
    end
  end

end