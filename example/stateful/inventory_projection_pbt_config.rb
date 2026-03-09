# frozen_string_literal: true

InventoryProjectionPbtConfig = {
  sut_factory: -> { InventoryProjectionImpl.new },
  initial_state: { adjustments: [], stock: 0 },
  command_mappings: {
    receive: {
      method: :receive,
      model_arg_adapter: ->(args) { args.abs + 1 },
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed inventory projection after receive to match model" unless observed_state == after_state
      end
    },
    ship: {
      method: :ship,
      model_arg_adapter: ->(args) { args.abs + 1 },
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed inventory projection after ship to match model" unless observed_state == after_state
      end
    }
  },
  verify_context: {
    state_reader: ->(sut) { { adjustments: sut.adjustments.dup, stock: sut.stock } }
  }
}
