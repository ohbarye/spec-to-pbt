# frozen_string_literal: true

# Regeneration-safe customization file for connection_pool stateful scaffold.
# Edit this file to map spec command names to your real Ruby API.
# This file is user-owned and should not be overwritten automatically.

ConnectionPoolPbtConfig = {
  sut_factory: -> { ConnectionPoolImpl.new },
  # initial_state: { available: 0, checked_out: 0, capacity: 3 },
  command_mappings: {
    checkout: {
      method: :checkout,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # next_state_override: ->(state, args) { state },
      # Suggested failure/no-op handling: if your API still exposes invalid calls, use applicable_override or verify_override to assert rejection or unchanged observed state
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed state to match model\" unless observed_state == after_state }
    },
    checkin: {
      method: :checkin,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # next_state_override: ->(state, args) { state },
      # Suggested failure/no-op handling: if your API still exposes invalid calls, use applicable_override or verify_override to assert rejection or unchanged observed state
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed state to match model\" unless observed_state == after_state }
    }
  },
  verify_context: {
    state_reader: nil, # suggested: ->(sut) { { available: sut.available, checked_out: sut.checked_out, capacity: sut.capacity } }
  }
  # before_run: ->(sut) { },
  # after_run: ->(sut, result) { }
}