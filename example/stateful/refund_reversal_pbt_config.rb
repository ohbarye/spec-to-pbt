# frozen_string_literal: true

RefundReversalPbtConfig = {
  sut_factory: -> { RefundReversalImpl.new },
  initial_state: { captured: 0, refunded: 0 },
  command_mappings: {
    capture: {
      method: :capture,
      model_arg_adapter: ->(args) { args.abs + 1 },
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed settlement state after capture to match model" unless observed_state == after_state
      end
    },
    refund: {
      method: :refund,
      model_arg_adapter: ->(args) { args.abs + 1 },
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed settlement state after refund to match model" unless observed_state == after_state
      end
    },
    reverse: {
      method: :reverse,
      model_arg_adapter: ->(args) { args.abs + 1 },
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed settlement state after reversal to match model" unless observed_state == after_state
      end
    }
  },
  verify_context: {
    state_reader: ->(sut) { { captured: sut.captured, refunded: sut.refunded } }
  }
}
