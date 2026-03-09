# frozen_string_literal: true

# Regeneration-safe customization file for job_queue_retry_dead_letter stateful scaffold.
# Edit this file to map spec command names to your real Ruby API.
# This file is user-owned and should not be overwritten automatically.

JobQueueRetryDeadLetterPbtConfig = {
  sut_factory: -> { JobQueueRetryDeadLetterImpl.new },
  # initial_state: { ready: 0, in_flight: 0, dead_letter: 0 },
  command_mappings: {
    enqueue: {
      method: :enqueue,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # next_state_override: ->(state, args) { state },
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed state to match model\" unless observed_state == after_state }
    },
    dispatch: {
      method: :dispatch,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # next_state_override: ->(state, args) { state },
      # guard_failure_policy: :no_op, # or :raise
      # Suggested failure/no-op handling: if your API still exposes invalid calls, guard_failure_policy lets the scaffold assert unchanged state or captured exceptions before falling back to verify_override
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed state to match model\" unless observed_state == after_state }
    },
    ack: {
      method: :ack,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # next_state_override: ->(state, args) { state },
      # guard_failure_policy: :no_op, # or :raise
      # Suggested failure/no-op handling: if your API still exposes invalid calls, guard_failure_policy lets the scaffold assert unchanged state or captured exceptions before falling back to verify_override
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed state to match model\" unless observed_state == after_state }
    },
    retry: {
      method: :retry,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # next_state_override: ->(state, args) { state },
      # guard_failure_policy: :no_op, # or :raise
      # Suggested failure/no-op handling: if your API still exposes invalid calls, guard_failure_policy lets the scaffold assert unchanged state or captured exceptions before falling back to verify_override
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed state to match model\" unless observed_state == after_state }
    },
    dead_letter: {
      method: :dead_letter,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # next_state_override: ->(state, args) { state },
      # guard_failure_policy: :no_op, # or :raise
      # Suggested failure/no-op handling: if your API still exposes invalid calls, guard_failure_policy lets the scaffold assert unchanged state or captured exceptions before falling back to verify_override
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed state to match model\" unless observed_state == after_state }
    }
  },
  verify_context: {
    state_reader: nil, # suggested: ->(sut) { { ready: sut.ready, in_flight: sut.in_flight, dead_letter: sut.dead_letter } }
  }
  # before_run: ->(sut) { },
  # after_run: ->(sut, result) { }
}