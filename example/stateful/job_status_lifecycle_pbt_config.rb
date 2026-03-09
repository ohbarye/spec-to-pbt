# frozen_string_literal: true

JobStatusLifecyclePbtConfig = {
  sut_factory: -> { JobStatusLifecycleImpl.new(status: 0) },
  initial_state: 0,
  command_mappings: {
    start: {
      method: :start,
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed job status after start to match model" unless observed_state == after_state
      end
    },
    complete: {
      method: :complete,
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed job status after complete to match model" unless observed_state == after_state
      end
    },
    fail: {
      method: :mark_failed,
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed job status after fail to match model" unless observed_state == after_state
      end
    },
    dead_letter: {
      method: :move_to_dead_letter,
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed job status after dead-letter to match model" unless observed_state == after_state
      end
    }
  },
  verify_context: {
    state_reader: ->(sut) { sut.status }
  }
}
