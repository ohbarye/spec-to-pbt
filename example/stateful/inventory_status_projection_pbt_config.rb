# frozen_string_literal: true

InventoryStatusProjectionPbtConfig = {
  sut_factory: -> { InventoryStatusProjectionImpl.new(status: 0, movements: [], stock: 0) },
  initial_state: { movements: [], status: 0, stock: 0 },
  command_mappings: {
    activate: {
      method: :activate,
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed inventory projection state after activate to match model" unless observed_state == after_state
      end
    },
    receive: {
      method: :receive,
      model_arg_adapter: ->(args) { args.abs + 1 },
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed inventory projection state after receive to match model" unless observed_state == after_state
      end
    },
    deactivate: {
      method: :deactivate,
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed inventory projection state after deactivate to match model" unless observed_state == after_state
      end
    }
  },
  verify_context: {
    state_reader: ->(sut) { { movements: sut.movements.dup, status: sut.status, stock: sut.stock } }
  }
}
