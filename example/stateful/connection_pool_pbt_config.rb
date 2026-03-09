# frozen_string_literal: true

ConnectionPoolPbtConfig = {
  sut_factory: -> { ConnectionPoolImpl.new(capacity: 3, available: 3, checked_out: 0) },
  initial_state: { available: 3, checked_out: 0, capacity: 3 },
  command_mappings: {
    checkout: {
      method: :checkout,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed pool state after checkout to match model" unless observed_state == after_state
      end
    },
    checkin: {
      method: :checkin,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed pool state after checkin to match model" unless observed_state == after_state
      end
    }
  },
  verify_context: {
    state_reader: ->(sut) { { available: sut.available, checked_out: sut.checked_out, capacity: sut.capacity } }
  }
}
