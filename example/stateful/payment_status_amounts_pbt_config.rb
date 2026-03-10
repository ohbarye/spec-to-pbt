# frozen_string_literal: true

PaymentStatusAmountsPbtConfig = {
  sut_factory: -> { PaymentStatusAmountsImpl.new(status: 0, authorized_amount: 0, captured_amount: 0) },
  initial_state: { status: 0, authorized_amount: 0, captured_amount: 0 },
  command_mappings: {
    authorize_amount: {
      method: :authorize_amount,
      model_arg_adapter: ->(args) { args.abs + 1 },
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed payment amounts after authorize_amount to match model" unless observed_state == after_state
      end
    },
    capture_amount: {
      method: :capture_amount,
      model_arg_adapter: ->(args) { args.abs + 1 },
      applicable_override: ->(state, args) { state[:status] == 1 && args.abs + 1 <= state[:authorized_amount] },
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed payment amounts after capture_amount to match model" unless observed_state == after_state
      end
    },
    reset: {
      method: :reset,
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed payment amounts after reset to match model" unless observed_state == after_state
      end
    }
  },
  verify_context: {
    state_reader: ->(sut) { { status: sut.status, authorized_amount: sut.authorized_amount, captured_amount: sut.captured_amount } }
  }
}
