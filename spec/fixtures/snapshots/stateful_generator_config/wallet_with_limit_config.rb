# frozen_string_literal: true

# Regeneration-safe customization file for wallet_with_limit stateful scaffold.
# Edit this file to map spec command names to your real Ruby API.
# This file is user-owned and should not be overwritten automatically.

WalletWithLimitPbtConfig = {
  sut_factory: -> { WalletWithLimitImpl.new },
  # initial_state: { balance: 0, credit_limit: 3 },
  command_mappings: {
    deposit: {
      method: :deposit,
      # Suggested real API methods: :credit_one, :credit
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed balance to match model\" unless observed_state == after_state }
    },
    withdraw: {
      method: :withdraw,
      # Suggested real API methods: :debit_one, :debit
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # Suggested failure/no-op handling: if your API still exposes invalid calls, use applicable_override or verify_override to assert rejection or unchanged observed state
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed balance to match model\" unless observed_state == after_state }
    }
  },
  verify_context: {
    state_reader: nil, # suggested: ->(sut) { { balance: sut.balance, credit_limit: sut.credit_limit } }
  }
  # before_run: ->(sut) { },
  # after_run: ->(sut, result) { }
}