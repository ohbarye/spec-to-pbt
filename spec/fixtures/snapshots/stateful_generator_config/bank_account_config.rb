# frozen_string_literal: true

# Regeneration-safe customization file for bank_account stateful scaffold.
# Edit this file to map spec command names to your real Ruby API.
# This file is user-owned and should not be overwritten automatically.

BankAccountPbtConfig = {
  sut_factory: -> { BankAccountImpl.new },
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
    deposit_amount: {
      method: :deposit_amount,
      # Suggested real API methods: :credit, :deposit
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
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed balance to match model\" unless observed_state == after_state }
    },
    withdraw_amount: {
      method: :withdraw_amount,
      # Suggested real API methods: :debit, :withdraw
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args.abs + 1 }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true },
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed balance to match model\" unless observed_state == after_state }
    }
  },
  verify_context: {
    state_reader: nil, # suggested: ->(sut) { sut.balance }
  }
  # before_run: ->(sut) { },
  # after_run: ->(sut, result) { }
}