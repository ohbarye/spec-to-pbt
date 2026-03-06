# frozen_string_literal: true

require "pbt"
require "rspec"
require_relative "thermostat_impl"

RSpec.describe "thermostat (stateful scaffold)" do
  it "wires a stateful PBT scaffold (customize before enabling)" do
    unless ENV["ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD"] == "1"
      skip "Set ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 after customizing the generated scaffold"
    end

    Pbt.assert(worker: :none, num_runs: 5, seed: 1) do
      Pbt.stateful(
        model: ThermostatModel.new,
        sut: -> { ThermostatImpl.new },
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

    def applicable?(_state)
      true
    end

    def next_state(state, _args)
      state # TODO: replace Thermostat#target using args
    end

    def run!(sut, args)
      if args.nil?
        sut.public_send(:set_target)
      elsif args.is_a?(Array)
        sut.public_send(:set_target, *args)
      else
        sut.public_send(:set_target, args)
      end
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#t'.target=next"
      # Analyzer hints: state_field="target", size_delta=nil, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:replace_like, command_confidence=:medium, guard_kind=:none, rhs_source_kind=:arg, state_update_shape=:replace_with_arg
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Thermostat#target
      # TODO: verify replaced value for Thermostat#target using args
      # Example shape: compare the inferred target against the command argument
      [sut, args] && nil
    end
  end

end