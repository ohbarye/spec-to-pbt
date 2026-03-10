# frozen_string_literal: true

JobStatusEventCountersPbtConfig = {
  sut_factory: -> { JobStatusEventCountersImpl.new(status: 0, events: [], retry_budget: 3, retry_count: 0) },
  initial_state: { events: [], status: 0, retry_budget: 3, retry_count: 0 },
  command_mappings: {
    activate: {
      method: :activate,
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed job event state after activate to match model" unless observed_state == after_state
      end
    },
    retry: {
      method: :retry,
      applicable_override: ->(state, _args = nil) { state[:status] == 1 && state[:retry_budget] > 0 },
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed job event state after retry to match model" unless observed_state == after_state
      end
    },
    deactivate: {
      method: :deactivate,
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed job event state after deactivate to match model" unless observed_state == after_state
      end
    }
  },
  verify_context: {
    state_reader: ->(sut) { { events: sut.events.dup, status: sut.status, retry_budget: sut.retry_budget, retry_count: sut.retry_count } }
  }
}
