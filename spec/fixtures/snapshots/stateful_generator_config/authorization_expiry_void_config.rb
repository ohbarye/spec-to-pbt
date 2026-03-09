# frozen_string_literal: true

# Regeneration-safe customization file for authorization_expiry_void stateful scaffold.
# Edit this file to map spec command names to your real Ruby API.
# This file is user-owned and should not be overwritten automatically.

AuthorizationExpiryVoidPbtConfig = {
  sut_factory: -> { AuthorizationExpiryVoidImpl.new },
  # initial_state: { available: 0, held: 0 },
  command_mappings: {
    authorize: {
      method: :authorize,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args.abs + 1 }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # next_state_override: ->(state, args) { state },
      # guard_failure_policy: :no_op, # or :raise
      # Suggested failure/no-op handling: if your API still exposes invalid calls, guard_failure_policy lets the scaffold assert unchanged state or captured exceptions before falling back to verify_override
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed state to match model\" unless observed_state == after_state }
    },
    void: {
      method: :void,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args.abs + 1 }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # next_state_override: ->(state, args) { state },
      # guard_failure_policy: :no_op, # or :raise
      # Suggested failure/no-op handling: if your API still exposes invalid calls, guard_failure_policy lets the scaffold assert unchanged state or captured exceptions before falling back to verify_override
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed state to match model\" unless observed_state == after_state }
    },
    expire: {
      method: :expire,
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
    state_reader: nil, # suggested: ->(sut) { { available: sut.available, held: sut.held } }
  }
  # before_run: ->(sut) { },
  # after_run: ->(sut, result) { }
}