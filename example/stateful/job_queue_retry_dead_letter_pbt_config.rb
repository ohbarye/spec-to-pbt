# frozen_string_literal: true

JobQueueRetryDeadLetterPbtConfig = {
  sut_factory: -> { JobQueueRetryDeadLetterImpl.new(ready: 2, in_flight: 0, dead_letter: 0) },
  initial_state: { ready: 2, in_flight: 0, dead_letter: 0 },
  command_mappings: {
    enqueue: {
      method: :enqueue,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed job queue state after enqueue to match model" unless observed_state == after_state
      end
    },
    dispatch: {
      method: :dispatch,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed job queue state after dispatch to match model" unless observed_state == after_state
      end
    },
    ack: {
      method: :ack,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed job queue state after ack to match model" unless observed_state == after_state
      end
    },
    retry: {
      method: :retry,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed job queue state after retry to match model" unless observed_state == after_state
      end
    },
    dead_letter: {
      method: :move_to_dead_letter,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed job queue state after dead-letter to match model" unless observed_state == after_state
      end
    }
  },
  verify_context: {
    state_reader: ->(sut) { { ready: sut.ready, in_flight: sut.in_flight, dead_letter: sut.dead_letter_count } }
  }
}
