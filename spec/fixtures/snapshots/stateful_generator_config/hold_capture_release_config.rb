# frozen_string_literal: true

# Regeneration-safe customization file for hold_capture_release stateful scaffold.
# Edit this file to map spec command names to your real Ruby API.
# This file is user-owned and should not be overwritten automatically.

HoldCaptureReleasePbtConfig = {
  sut_factory: -> { HoldCaptureReleaseImpl.new },
  command_mappings: {
    hold: {
      method: :hold,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args },
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed state to match model\" unless observed_state == after_state }
    },
    capture: {
      method: :capture,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args },
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed state to match model\" unless observed_state == after_state }
    },
    release: {
      method: :release,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args },
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed state to match model\" unless observed_state == after_state }
    }
  },
  verify_context: {
    state_reader: nil, # suggested: ->(sut) { { available: sut.available, held: sut.held } }
  }
  # before_run: ->(sut) { },
  # after_run: ->(sut, result) { }
}