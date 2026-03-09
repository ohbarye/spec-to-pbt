# frozen_string_literal: true

# Regeneration-safe customization file for inventory_projection stateful scaffold.
# Edit this file to map spec command names to your real Ruby API.
# This file is user-owned and should not be overwritten automatically.

InventoryProjectionPbtConfig = {
  sut_factory: -> { InventoryProjectionImpl.new },
  # initial_state: { adjustments: [], stock: 0 },
  command_mappings: {
    receive: {
      method: :receive,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true }, # use this for unsupported guards or richer domain preconditions
      # next_state_override: ->(state, args) { state }, # use this when invalid paths or derived state need a domain-specific model transition
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed collection state to match model\" unless observed_state == after_state } # use this for observed-state checks and lifecycle/business-rule-heavy invalid-path semantics
    },
    ship: {
      method: :ship,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true }, # use this for unsupported guards or richer domain preconditions
      # next_state_override: ->(state, args) { state }, # use this when invalid paths or derived state need a domain-specific model transition
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed collection state to match model\" unless observed_state == after_state } # use this for observed-state checks and lifecycle/business-rule-heavy invalid-path semantics
    }
  },
  verify_context: {
    state_reader: nil, # suggested: ->(sut) { { adjustments: sut.adjustments.dup, stock: sut.stock } }
  }
  # before_run: ->(sut) { },
  # after_run: ->(sut, result) { }
}