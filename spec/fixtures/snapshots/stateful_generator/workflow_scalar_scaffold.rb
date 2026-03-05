# frozen_string_literal: true

require "pbt"
require "rspec"
require_relative "workflow_impl"

RSpec.describe "workflow (stateful scaffold)" do
  it "wires a stateful PBT scaffold (customize before enabling)" do
    unless ENV["ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD"] == "1"
      skip "Set ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 after customizing the generated scaffold"
    end

    Pbt.assert(worker: :none, num_runs: 5, seed: 1) do
      Pbt.stateful(
        model: WorkflowModel.new,
        sut: -> { WorkflowImpl.new },
        max_steps: 20
      )
    end
  end

  class WorkflowModel
    def initialize
      @commands = [
        StepCommand.new
      ]
    end

    def initial_state
      nil # TODO: replace with a domain-specific scalar/model state
    end

    def commands(_state)
      @commands
    end
  end

  class StepCommand
    def name
      :step
    end

    def arguments
      Pbt.integer # placeholder for Token
    end

    def applicable?(_state)
      true
    end

    def next_state(state, _args)
      state # TODO: update Machine#value based on args/result
    end

    def run!(sut, args)
      if args.nil?
        sut.public_send(:step)
      elsif args.is_a?(Array)
        sut.public_send(:step, *args)
      else
        sut.public_send(:step, args)
      end
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#m'.value = add[#m.value, 1]"
      # Analyzer hints: state_field="value", size_delta=1, transition_kind=:append, requires_non_empty_state=false, scalar_update_kind=:increment_like, command_confidence=:high
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Machine#value
      # TODO: verify incremented value for Machine#value
      [sut, args] && nil
    end
  end

end