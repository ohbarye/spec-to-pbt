# frozen_string_literal: true

# Regeneration-safe customization file for stack stateful scaffold.
# Edit this file to map spec command names to your real Ruby API.
# This file is user-owned and should not be overwritten automatically.

StackPbtConfig = {
  sut_factory: -> { StackImpl.new },
  command_mappings: {
    push_adds_element: {
      method: :push_adds_element,
      # Suggested real API method: :push
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args },
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # verify_override: ->(before_state:, after_state:, args:, result:, sut:, observed_state:) { nil }
    },
    pop_removes_element: {
      method: :pop_removes_element,
      # Suggested real API method: :pop
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args },
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # verify_override: ->(before_state:, after_state:, args:, result:, sut:, observed_state:) { nil }
    }
  },
  verify_context: {
    state_reader: nil
  }
  # before_run: ->(sut) { },
  # after_run: ->(sut, result) { }
}