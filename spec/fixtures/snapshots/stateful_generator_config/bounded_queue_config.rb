# frozen_string_literal: true

# Regeneration-safe customization file for bounded_queue stateful scaffold.
# Edit this file to map spec command names to your real Ruby API.
# This file is user-owned and should not be overwritten automatically.

BoundedQueuePbtConfig = {
  sut_factory: -> { BoundedQueueImpl.new },
  # initial_state: { elements: [], capacity: 3 },
  command_mappings: {
    enqueue: {
      method: :enqueue,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # next_state_override: ->(state, args) { state },
      # guard_failure_policy: :no_op, # or :raise / :custom
      # Suggested failure/no-op handling: use :no_op for unchanged-state invalid calls, :raise for captured exceptions, or :custom with verify_override when the invalid path is domain-specific
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed collection state to match model\" unless observed_state == after_state[:elements] }
    },
    dequeue: {
      method: :dequeue,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # next_state_override: ->(state, args) { state },
      # guard_failure_policy: :no_op, # or :raise / :custom
      # Suggested failure/no-op handling: use :no_op for unchanged-state invalid calls, :raise for captured exceptions, or :custom with verify_override when the invalid path is domain-specific
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed collection state to match model\" unless observed_state == after_state[:elements] }
    }
  },
  verify_context: {
    state_reader: nil, # suggested: ->(sut) { sut.snapshot }
  }
  # before_run: ->(sut) { },
  # after_run: ->(sut, result) { }
}