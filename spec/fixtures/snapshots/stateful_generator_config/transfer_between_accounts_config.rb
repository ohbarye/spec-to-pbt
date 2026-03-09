# frozen_string_literal: true

# Regeneration-safe customization file for transfer_between_accounts stateful scaffold.
# Edit this file to map spec command names to your real Ruby API.
# This file is user-owned and should not be overwritten automatically.

TransferBetweenAccountsPbtConfig = {
  sut_factory: -> { TransferBetweenAccountsImpl.new },
  # initial_state: { source_balance: 0, target_balance: 0 },
  command_mappings: {
    transfer: {
      method: :transfer,
      # Suggested real API methods: :move_funds, :transfer_amount, :post_transfer
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args.abs + 1 }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # next_state_override: ->(state, args) { state },
      # guard_failure_policy: :no_op, # or :raise
      # Suggested failure/no-op handling: if your API still exposes invalid calls, guard_failure_policy lets the scaffold assert unchanged state or captured exceptions before falling back to verify_override
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed account balances to match model\" unless observed_state == after_state }
    }
  },
  verify_context: {
    state_reader: nil, # suggested: ->(sut) { { source_balance: sut.source_balance, target_balance: sut.target_balance } }
  }
  # before_run: ->(sut) { },
  # after_run: ->(sut, result) { }
}