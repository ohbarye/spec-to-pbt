# frozen_string_literal: true

# Regeneration-safe customization file for feature_flag_rollout stateful scaffold.
# Edit this file to map spec command names to your real Ruby API.
# This file is user-owned and should not be overwritten automatically.

FeatureFlagRolloutPbtConfig = {
  sut_factory: -> { FeatureFlagRolloutImpl.new },
  # initial_state: { rollout: 0, max_rollout: 3 },
  command_mappings: {
    enable: {
      method: :enable,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # next_state_override: ->(state, args) { state },
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed state to match model\" unless observed_state == after_state }
    },
    disable: {
      method: :disable,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # next_state_override: ->(state, args) { state },
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed state to match model\" unless observed_state == after_state }
    },
    rollout: {
      method: :rollout,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # next_state_override: ->(state, args) { state },
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed state to match model\" unless observed_state == after_state }
    }
  },
  verify_context: {
    state_reader: nil, # suggested: ->(sut) { { rollout: sut.rollout, max_rollout: sut.max_rollout } }
  }
  # before_run: ->(sut) { },
  # after_run: ->(sut, result) { }
}