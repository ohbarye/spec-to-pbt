# frozen_string_literal: true

# Regeneration-safe customization file for stack stateful scaffold.
# Edit this file to map spec command names to your real Ruby API.
# This file is user-owned and should not be overwritten automatically.

StackPbtConfig = {
  sut_factory: -> { StackImpl.new },
  # initial_state: [],
  command_mappings: {
    push_adds_element: {
      method: :push_adds_element,
      # Suggested real API methods: :push
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # next_state_override: ->(state, args) { state },
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed collection state to match model\" unless observed_state == after_state }
    },
    pop_removes_element: {
      method: :pop_removes_element,
      # Suggested real API methods: :pop
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # next_state_override: ->(state, args) { state },
      # Suggested failure/no-op handling: if your API still exposes invalid calls, use applicable_override or verify_override to assert rejection or unchanged observed state
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed collection state to match model\" unless observed_state == after_state }
    }
  },
  verify_context: {
    state_reader: nil, # suggested: ->(sut) { sut.snapshot }
  }
  # before_run: ->(sut) { },
  # after_run: ->(sut, result) { }
}