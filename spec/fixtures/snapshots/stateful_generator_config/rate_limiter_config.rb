# frozen_string_literal: true

# Regeneration-safe customization file for rate_limiter stateful scaffold.
# Edit this file to map spec command names to your real Ruby API.
# This file is user-owned and should not be overwritten automatically.

RateLimiterPbtConfig = {
  sut_factory: -> { RateLimiterImpl.new },
  # initial_state: { remaining: 0, capacity: 3 },
  command_mappings: {
    allow: {
      method: :allow,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # next_state_override: ->(state, args) { state },
      # Suggested failure/no-op handling: if your API still exposes invalid calls, use applicable_override or verify_override to assert rejection or unchanged observed state
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed state to match model\" unless observed_state == after_state }
    },
    reset: {
      method: :reset,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # next_state_override: ->(state, args) { state },
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed state to match model\" unless observed_state == after_state }
    }
  },
  verify_context: {
    state_reader: nil, # suggested: ->(sut) { { remaining: sut.remaining, capacity: sut.capacity } }
  }
  # before_run: ->(sut) { },
  # after_run: ->(sut, result) { }
}