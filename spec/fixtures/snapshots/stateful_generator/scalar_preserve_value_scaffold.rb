# frozen_string_literal: true

require "pbt"
require "rspec"
require_relative "box_impl"

RSpec.describe "box (stateful scaffold)" do
  it "wires a stateful PBT scaffold (customize before enabling)" do
    unless ENV["ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD"] == "1"
      skip "Set ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 after customizing the generated scaffold"
    end

    Pbt.assert(worker: :none, num_runs: 5, seed: 1) do
      Pbt.stateful(
        model: BoxModel.new,
        sut: -> { BoxImpl.new },
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
      nil # TODO: replace with a domain-specific scalar/model state
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

    def applicable?(_state)
      true
    end

    def next_state(state, _args)
      state # TODO: keep Box#value stable unless other domain state changes
    end

    def run!(sut, args)
      if args.nil?
        sut.public_send(:keep)
      elsif args.is_a?(Array)
        sut.public_send(:keep, *args)
      else
        sut.public_send(:keep, args)
      end
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#b'.value=#b.value"
      # Analyzer hints: state_field="value", size_delta=0, transition_kind=:size_no_change, requires_non_empty_state=false, scalar_update_kind=:replace_like, command_confidence=:medium, guard_kind=:none, rhs_source_kind=:state_field, state_update_shape=:preserve_value
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Box#value
      raise "Expected preserved value for Box#value" unless after_state == before_state
      # Example shape: replace this equality check with a narrower field-level assertion if needed
      [sut, args] && nil
    end
  end

end