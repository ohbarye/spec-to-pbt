# frozen_string_literal: true

BoundedQueuePbtConfig = {
  sut_factory: -> { BoundedQueueImpl.new(capacity: 3) },
  command_mappings: {
    enqueue: {
      method: :enqueue,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed queue state after enqueue to match model" unless observed_state == after_state[:elements]
      end
    },
    dequeue: {
      method: :dequeue,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed queue state after dequeue to match model" unless observed_state == after_state[:elements]
      end
    }
  },
  verify_context: {
    state_reader: ->(sut) { sut.snapshot }
  }
}
