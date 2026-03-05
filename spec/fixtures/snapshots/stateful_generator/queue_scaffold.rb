# frozen_string_literal: true

require "pbt"
require "rspec"
require_relative "queue_impl"

RSpec.describe "queue (stateful scaffold)" do
  it "wires a stateful PBT scaffold (customize before enabling)" do
    unless ENV["ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD"] == "1"
      skip "Set ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 after customizing the generated scaffold"
    end

    Pbt.assert(worker: :none, num_runs: 5, seed: 1) do
      Pbt.stateful(
        model: QueueModel.new,
        sut: -> { QueueImpl.new },
        max_steps: 20
      )
    end
  end

  class QueueModel
    def initialize
      @commands = [
        EnqueueCommand.new,
        DequeueCommand.new
      ]
    end

    def initial_state
      [] # TODO: replace with a domain-specific collection state
    end

    def commands(_state)
      @commands
    end
  end

  class EnqueueCommand
    def name
      :enqueue
    end

    def arguments
      Pbt.integer # placeholder for Element
    end

    def applicable?(_state)
      true
    end

    def next_state(state, args)
      # Inferred transition target: Queue#elements
      state + [args]
    end

    def run!(sut, args)
      if args.nil?
        sut.public_send(:enqueue)
      elsif args.is_a?(Array)
        sut.public_send(:enqueue, *args)
      else
        sut.public_send(:enqueue, args)
      end
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#q'.elements = add[#q.elements, 1]"
      # Analyzer hints: state_field="elements", size_delta=1, transition_kind=:append, requires_non_empty_state=false, scalar_update_kind=nil, command_confidence=:high
      # Related Alloy assertions: QueueProperties
      # Assertion/fact pattern hints: empty
      # Related Alloy property predicates: EnqueueDequeueIdentity, IsEmpty, FIFO
      # Related property predicate pattern hints: size, empty, ordering
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      # Inferred collection target: Queue#elements
      expected_size = before_state.length + 1
      raise "Expected size to increase by 1" unless after_state.length == expected_size
      [sut, args] && nil
    end
  end

  class DequeueCommand
    def name
      :dequeue
    end

    def arguments
      Pbt.nil
    end

    def applicable?(state)
      !state.empty? # inferred precondition for dequeue
    end

    def next_state(state, _args)
      # Inferred transition target: Queue#elements
      state.drop(1)
    end

    def run!(sut, args)
      if args.nil?
        sut.public_send(:dequeue)
      elsif args.is_a?(Array)
        sut.public_send(:dequeue, *args)
      else
        sut.public_send(:dequeue, args)
      end
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#q.elements > 0 implies #q'.elements = sub[#q.elements, 1]"
      # Analyzer hints: state_field="elements", size_delta=-1, transition_kind=:dequeue, requires_non_empty_state=true, scalar_update_kind=nil, command_confidence=:high
      # Related Alloy assertions: QueueProperties
      # Assertion/fact pattern hints: empty
      # Related Alloy property predicates: EnqueueDequeueIdentity, IsEmpty, FIFO
      # Related property predicate pattern hints: size, empty, ordering
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      # Inferred collection target: Queue#elements
      expected = before_state.first
      raise "Expected dequeued value to match model" unless result == expected
      raise "Expected size to decrease by 1" unless after_state.length == before_state.length - 1
      [sut, args] && nil
    end
  end

end