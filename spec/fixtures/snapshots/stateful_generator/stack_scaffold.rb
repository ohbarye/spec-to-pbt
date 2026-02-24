# frozen_string_literal: true

require "pbt"
require "rspec"
require_relative "stack_impl"

RSpec.describe "stack (stateful scaffold)" do
  it "wires a stateful PBT scaffold (customize before enabling)" do
    unless ENV["ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD"] == "1"
      skip "Set ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 after customizing the generated scaffold"
    end

    Pbt.assert(worker: :none, num_runs: 5, seed: 1) do
      Pbt.stateful(
        model: StackModel.new,
        sut: -> { StackImpl.new },
        max_steps: 20
      )
    end
  end

  class StackModel
    def initialize
      @commands = [
        PushAddsElementCommand.new,
        PopRemovesElementCommand.new
      ]
    end

    def initial_state
      [] # TODO: replace with a domain-specific model state
    end

    def commands(_state)
      @commands
    end
  end

  class PushAddsElementCommand
    def name
      :push_adds_element
    end

    def arguments
      Pbt.integer # placeholder for Element
    end

    def applicable?(_state)
      true
    end

    def next_state(state, args)
      state + [args]
    end

    def run!(sut, args)
      if args.nil?
        sut.public_send(:push_adds_element)
      elsif args.is_a?(Array)
        sut.public_send(:push_adds_element, *args)
      else
        sut.public_send(:push_adds_element, args)
      end
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#s'.elements = add[#s.elements, 1]"
      # Analyzer hints: size_delta=1, requires_non_empty_state=false
      # Related Alloy assertions: StackProperties
      # Assertion/fact pattern hints: empty
      # Related Alloy property predicates: PushPopIdentity, IsEmpty, LIFO
      # Related property predicate pattern hints: roundtrip, size, empty, ordering
      expected_size = before_state.length + 1
      raise "Expected size to increase by 1" unless after_state.length == expected_size
      [sut, args] && nil
    end
  end

  class PopRemovesElementCommand
    def name
      :pop_removes_element
    end

    def arguments
      Pbt.nil
    end

    def applicable?(state)
      !state.empty? # inferred precondition for pop_removes_element
    end

    def next_state(state, _args)
      state[0...-1]
    end

    def run!(sut, args)
      if args.nil?
        sut.public_send(:pop_removes_element)
      elsif args.is_a?(Array)
        sut.public_send(:pop_removes_element, *args)
      else
        sut.public_send(:pop_removes_element, args)
      end
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#s.elements > 0 implies #s'.elements = sub[#s.elements, 1]"
      # Analyzer hints: size_delta=-1, requires_non_empty_state=true
      # Related Alloy assertions: StackProperties
      # Assertion/fact pattern hints: empty
      # Related Alloy property predicates: PushPopIdentity, IsEmpty, LIFO
      # Related property predicate pattern hints: roundtrip, size, empty, ordering
      expected = before_state.last
      raise "Expected popped value to match model" unless result == expected
      raise "Expected size to decrease by 1" unless after_state.length == before_state.length - 1
      [sut, args] && nil
    end
  end

end