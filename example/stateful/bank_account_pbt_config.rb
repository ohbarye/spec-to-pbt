# frozen_string_literal: true

BankAccountPbtConfig = {
  sut_factory: -> { BankAccountImpl.new },
  command_mappings: {
    deposit_amount: {
      method: :credit,
      model_arg_adapter: ->(args) { args.abs + 1 },
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed balance after credit to match model" unless observed_state == after_state
      end
    },
    withdraw: {
      method: :debit,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed balance after debit to match model" unless observed_state == after_state
      end
    }
  },
  verify_context: {
    state_reader: ->(sut) { sut.balance }
  }
}
