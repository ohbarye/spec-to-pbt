# frozen_string_literal: true

# Regeneration-safe customization file for bounded_queue stateful scaffold.
# Edit this file to map spec command names to your real Ruby API.
# This file is user-owned and should not be overwritten automatically.

BoundedQueuePbtConfig = {
  sut_factory: -> { BoundedQueueImpl.new },
  command_mappings: {
    enqueue: {
      method: :enqueue,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args },
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed state to match model\" unless observed_state == after_state[:elements] }
    },
    dequeue: {
      method: :dequeue,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args },
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed state to match model\" unless observed_state == after_state[:elements] }
    }
  },
  verify_context: {
    state_reader: nil, # suggested: ->(sut) { sut.snapshot }
  }
  # before_run: ->(sut) { },
  # after_run: ->(sut, result) { }
}