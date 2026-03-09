# frozen_string_literal: true

PartialRefundRemainingCapturablePbtConfig = {
  sut_factory: -> { PartialRefundRemainingCapturableImpl.new(authorized: 20, captured: 0, refunded: 0) },
  initial_state: { authorized: 20, captured: 0, refunded: 0 },
  command_mappings: {
    capture: {
      method: :capture,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed payment state after capture to match model" unless observed_state == after_state
      end
    },
    refund: {
      method: :refund,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed payment state after refund to match model" unless observed_state == after_state
      end
    }
  },
  verify_context: {
    state_reader: ->(sut) { { authorized: sut.authorized, captured: sut.captured, refunded: sut.refunded } }
  }
}
