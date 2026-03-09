# frozen_string_literal: true

JobStatusCountersPbtConfig = {
  sut_factory: -> { JobStatusCountersImpl.new(status: 0, retry_count: 0, dead_letter_count: 0) },
  initial_state: { status: 0, retry_count: 0, dead_letter_count: 0 },
  command_mappings: {
    start: {
      method: :dispatch,
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed job counters after start to match model" unless observed_state == after_state
      end
    },
    retry: {
      method: :requeue,
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed job counters after retry to match model" unless observed_state == after_state
      end
    },
    dead_letter: {
      method: :move_to_dead_letter,
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed job counters after dead_letter to match model" unless observed_state == after_state
      end
    }
  },
  verify_context: {
    state_reader: ->(sut) { { status: sut.status, retry_count: sut.retry_count, dead_letter_count: sut.dead_letter_count } }
  }
}
