# frozen_string_literal: true

BoundedQueuePbtConfig = {
  sut_factory: -> { BoundedQueueImpl.new(capacity: 3) },
  command_mappings: {
    enqueue: {
      method: :enqueue,
      applicable_override: ->(state) { state.length < 3 },
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed queue state after enqueue to match model" unless observed_state == after_state
      end
    },
    dequeue: {
      method: :dequeue,
      applicable_override: ->(state) { !state.empty? },
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed queue state after dequeue to match model" unless observed_state == after_state
      end
    }
  },
  verify_context: {
    state_reader: ->(sut) { sut.snapshot }
  }
}
