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
      [] # TODO: replace with a domain-specific collection state
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
      # Inferred transition target: Stack#elements
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
      # Alloy predicate body (preview): "#s'.elements=add[#s.elements,1]"
      # Analyzer hints: state_field="elements", size_delta=1, transition_kind=:append, requires_non_empty_state=false, scalar_update_kind=nil, command_confidence=:high, guard_kind=:none, rhs_source_kind=:unknown, state_update_shape=:append_like
      # Related Alloy assertions: StackProperties
      # Related Alloy property predicates: PushPopIdentity, IsEmpty, LIFO
      # Related pattern hints: roundtrip, size, empty, ordering
      # Derived verify hints: respect_non_empty_guard, check_empty_semantics, check_ordering_semantics, check_roundtrip_pairing, check_size_semantics
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      # Inferred collection target: Stack#elements
      # Derived from related assertions/facts: respect the non-empty guard before removal-style checks
      # Derived from related property patterns: verify empty-state semantics for the inferred target
      # Derived from related property patterns: verify ordering semantics (for example LIFO/FIFO) where relevant
      # Derived from related property patterns: verify paired-command roundtrip behavior against sibling commands
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
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
      # Inferred transition target: Stack#elements
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
      # Alloy predicate body (preview): "#s.elements>0 implies#s'.elements=sub[#s.elements,1]"
      # Analyzer hints: state_field="elements", size_delta=-1, transition_kind=:pop, requires_non_empty_state=true, scalar_update_kind=nil, command_confidence=:high, guard_kind=:non_empty, rhs_source_kind=:unknown, state_update_shape=:remove_last
      # Related Alloy assertions: StackProperties
      # Related Alloy property predicates: PushPopIdentity, IsEmpty, LIFO
      # Related pattern hints: roundtrip, size, empty, ordering
      # Derived verify hints: respect_non_empty_guard, check_empty_semantics, check_ordering_semantics, check_roundtrip_pairing, check_size_semantics
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      # Inferred collection target: Stack#elements
      # Derived from related assertions/facts: respect the non-empty guard before removal-style checks
      # Derived from related property patterns: verify empty-state semantics for the inferred target
      # Derived from related property patterns: verify ordering semantics (for example LIFO/FIFO) where relevant
      # Derived from related property patterns: verify paired-command roundtrip behavior against sibling commands
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      raise "Expected non-empty state before removal" if before_state.empty?
      expected = before_state.last
      raise "Expected popped value to match model" unless result == expected
      raise "Expected size to decrease by 1" unless after_state.length == before_state.length - 1
      [sut, args] && nil
    end
  end

end