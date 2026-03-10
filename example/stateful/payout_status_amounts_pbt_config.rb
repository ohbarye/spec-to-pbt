# frozen_string_literal: true

PayoutStatusAmountsPbtConfig = {
  sut_factory: -> { PayoutStatusAmountsImpl.new(status: 0, pending_amount: 0, paid_amount: 0) },
  initial_state: { status: 0, pending_amount: 0, paid_amount: 0 },
  command_mappings: {
    queue_amount: {
      method: :queue_amount,
      model_arg_adapter: ->(args) { args.abs + 1 },
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed payout amounts after queue_amount to match model" unless observed_state == after_state
      end
    },
    complete_amount: {
      method: :complete_amount,
      model_arg_adapter: ->(args) { args.abs + 1 },
      applicable_override: ->(state, args) { state[:status] == 1 && args.abs + 1 <= state[:pending_amount] },
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed payout amounts after complete_amount to match model" unless observed_state == after_state
      end
    },
    reset: {
      method: :reset,
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed payout amounts after reset to match model" unless observed_state == after_state
      end
    }
  },
  verify_context: {
    state_reader: ->(sut) { { status: sut.status, pending_amount: sut.pending_amount, paid_amount: sut.paid_amount } }
  }
}
