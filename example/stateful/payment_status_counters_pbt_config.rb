# frozen_string_literal: true

PaymentStatusCountersPbtConfig = {
  sut_factory: -> { PaymentStatusCountersImpl.new(status: 0, authorized: 0, captured: 0) },
  initial_state: { status: 0, authorized: 0, captured: 0 },
  command_mappings: {
    authorize_one: {
      method: :authorize_one,
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed payment counters after authorize_one to match model" unless observed_state == after_state
      end
    },
    capture_one: {
      method: :capture_one,
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed payment counters after capture_one to match model" unless observed_state == after_state
      end
    },
    reset: {
      method: :reset,
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed payment counters after reset to match model" unless observed_state == after_state
      end
    }
  },
  verify_context: {
    state_reader: ->(sut) { { status: sut.status, authorized: sut.authorized, captured: sut.captured } }
  }
}
