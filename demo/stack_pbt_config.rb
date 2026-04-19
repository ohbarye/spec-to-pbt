# frozen_string_literal: true

StackPbtConfig = {
  sut_factory: -> { StackImpl.new },
  command_mappings: {
    push_adds_element: {
      method: :push,
      verify_override: ->(after_state:, observed_state:) do
        raise "Expected observed stack state after push to match model" unless observed_state == after_state
      end
    },
    pop_removes_element: {
      method: :pop,
      verify_override: ->(after_state:, observed_state:) do
        raise "Expected observed stack state after pop to match model" unless observed_state == after_state
      end
    }
  },
  verify_context: {
    state_reader: ->(sut) { sut.snapshot }
  }
}
