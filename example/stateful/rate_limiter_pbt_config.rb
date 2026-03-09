# frozen_string_literal: true

RateLimiterPbtConfig = {
  sut_factory: -> { RateLimiterImpl.new(capacity: 3, remaining: 3) },
  initial_state: { remaining: 3, capacity: 3 },
  command_mappings: {
    allow: {
      method: :allow,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed limiter state after allow to match model" unless observed_state == after_state
      end
    },
    reset: {
      method: :reset,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed limiter state after reset to match model" unless observed_state == after_state
      end
    }
  },
  verify_context: {
    state_reader: ->(sut) { { remaining: sut.remaining, capacity: sut.capacity } }
  }
}
