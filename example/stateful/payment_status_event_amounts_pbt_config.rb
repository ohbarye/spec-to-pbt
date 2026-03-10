# frozen_string_literal: true

PaymentStatusEventAmountsPbtConfig = {
  sut_factory: -> { PaymentStatusEventAmountsImpl.new(status: 0, captures: [], remaining_amount: 3, settled_amount: 0) },
  initial_state: { captures: [], status: 0, remaining_amount: 3, settled_amount: 0 },
  command_mappings: {
    open: {
      method: :open,
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed payment event state after open to match model" unless observed_state == after_state
      end
    },
    settle_unit: {
      method: :settle_unit,
      applicable_override: ->(state, _args = nil) { state[:status] == 1 && state[:remaining_amount] > 0 },
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed payment event state after settle_unit to match model" unless observed_state == after_state
      end
    },
    close: {
      method: :close,
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed payment event state after close to match model" unless observed_state == after_state
      end
    }
  },
  verify_context: {
    state_reader: ->(sut) { { captures: sut.captures.dup, status: sut.status, remaining_amount: sut.remaining_amount, settled_amount: sut.settled_amount } }
  }
}
