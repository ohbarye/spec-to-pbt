# frozen_string_literal: true

PaymentStatusLifecyclePbtConfig = {
  sut_factory: -> { PaymentStatusLifecycleImpl.new(status: 0) },
  initial_state: 0,
  command_mappings: {
    authorize: {
      method: :authorize,
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed payment status after authorize to match model" unless observed_state == after_state
      end
    },
    capture: {
      method: :capture,
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed payment status after capture to match model" unless observed_state == after_state
      end
    },
    void: {
      method: :void,
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed payment status after void to match model" unless observed_state == after_state
      end
    },
    refund: {
      method: :refund,
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed payment status after refund to match model" unless observed_state == after_state
      end
    }
  },
  verify_context: {
    state_reader: ->(sut) { sut.status }
  }
}
