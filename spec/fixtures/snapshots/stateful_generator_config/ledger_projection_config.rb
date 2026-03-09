# frozen_string_literal: true

# Regeneration-safe customization file for ledger_projection stateful scaffold.
# Edit this file to map spec command names to your real Ruby API.
# This file is user-owned and should not be overwritten automatically.

LedgerProjectionPbtConfig = {
  sut_factory: -> { LedgerProjectionImpl.new },
  # initial_state: nil,
  command_mappings: {
    post_credit: {
      method: :post_credit,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # next_state_override: ->(state, args) { state },
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed state to match model\" unless observed_state == after_state }
    },
    post_debit: {
      method: :post_debit,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # next_state_override: ->(state, args) { state },
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed state to match model\" unless observed_state == after_state }
    }
  },
  verify_context: {
    state_reader: nil, # suggested: expose a snapshot/reader for the model state
  }
  # before_run: ->(sut) { },
  # after_run: ->(sut, result) { }
}