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
      # Suggested failure/no-op handling: if your API still exposes invalid calls, use applicable_override or verify_override to assert rejection or unchanged observed state
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed account balances to match model\" unless observed_state == after_state }
    }
  },
  verify_context: {
    state_reader: nil, # suggested: ->(sut) { { source_balance: sut.source_balance, target_balance: sut.target_balance } }
  }
  # before_run: ->(sut) { },
  # after_run: ->(sut, result) { }
}