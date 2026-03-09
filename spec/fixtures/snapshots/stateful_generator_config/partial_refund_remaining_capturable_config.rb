# frozen_string_literal: true

# Regeneration-safe customization file for partial_refund_remaining_capturable stateful scaffold.
# Edit this file to map spec command names to your real Ruby API.
# This file is user-owned and should not be overwritten automatically.

PartialRefundRemainingCapturablePbtConfig = {
  sut_factory: -> { PartialRefundRemainingCapturableImpl.new },
  # initial_state: { authorized: 0, captured: 0, refunded: 0 },
  command_mappings: {
    capture: {
      method: :capture,
      # Suggested real API methods: :settle
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args.abs + 1 }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # next_state_override: ->(state, args) { state },
      # guard_failure_policy: :no_op, # or :raise
      # Suggested failure/no-op handling: if your API still exposes invalid calls, guard_failure_policy lets the scaffold assert unchanged state or captured exceptions before falling back to verify_override
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed state to match model\" unless observed_state == after_state }
    },
    refund: {
      method: :refund,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args.abs + 1 }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # next_state_override: ->(state, args) { state },
      # guard_failure_policy: :no_op, # or :raise
      # Suggested failure/no-op handling: if your API still exposes invalid calls, guard_failure_policy lets the scaffold assert unchanged state or captured exceptions before falling back to verify_override
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed state to match model\" unless observed_state == after_state }
    }
  },
  verify_context: {
    state_reader: nil, # suggested: ->(sut) { { authorized: sut.authorized, captured: sut.captured, refunded: sut.refunded } }
  }
  # before_run: ->(sut) { },
  # after_run: ->(sut, result) { }
}