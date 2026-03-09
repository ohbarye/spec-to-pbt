# frozen_string_literal: true

# Regeneration-safe customization file for hold_capture_release stateful scaffold.
# Edit this file to map spec command names to your real Ruby API.
# This file is user-owned and should not be overwritten automatically.

HoldCaptureReleasePbtConfig = {
  sut_factory: -> { HoldCaptureReleaseImpl.new },
  # initial_state: { available: 0, held: 0 },
  command_mappings: {
    hold: {
      method: :hold,
      # Suggested real API methods: :authorize, :reserve, :place_hold
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true }, # use this for unsupported guards or richer domain preconditions
      # next_state_override: ->(state, args) { state }, # use this when invalid paths or derived state need a domain-specific model transition
      # guard_failure_policy: :no_op, # or :raise / :custom
      # Suggested failure/no-op handling: use :no_op for unchanged-state invalid calls, :raise for captured exceptions, or :custom with verify_override when the invalid path is domain-specific
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed reservation state to match model\" unless observed_state == after_state } # use this for observed-state checks and lifecycle/business-rule-heavy invalid-path semantics
    },
    capture: {
      method: :capture,
      # Suggested real API methods: :settle
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true }, # use this for unsupported guards or richer domain preconditions
      # next_state_override: ->(state, args) { state }, # use this when invalid paths or derived state need a domain-specific model transition
      # guard_failure_policy: :no_op, # or :raise / :custom
      # Suggested failure/no-op handling: use :no_op for unchanged-state invalid calls, :raise for captured exceptions, or :custom with verify_override when the invalid path is domain-specific
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed reservation state to match model\" unless observed_state == after_state } # use this for observed-state checks and lifecycle/business-rule-heavy invalid-path semantics
    },
    release: {
      method: :release,
      # Suggested real API methods: :release_hold, :void_authorization
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true }, # use this for unsupported guards or richer domain preconditions
      # next_state_override: ->(state, args) { state }, # use this when invalid paths or derived state need a domain-specific model transition
      # guard_failure_policy: :no_op, # or :raise / :custom
      # Suggested failure/no-op handling: use :no_op for unchanged-state invalid calls, :raise for captured exceptions, or :custom with verify_override when the invalid path is domain-specific
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed reservation state to match model\" unless observed_state == after_state } # use this for observed-state checks and lifecycle/business-rule-heavy invalid-path semantics
    }
  },
  verify_context: {
    state_reader: nil, # suggested: ->(sut) { { available: sut.available, held: sut.held } }
  }
  # before_run: ->(sut) { },
  # after_run: ->(sut, result) { }
}