# frozen_string_literal: true

BankAccountPbtConfig = {
  sut_factory: -> { BankAccountImpl.new },
  command_mappings: {
    deposit: {
      method: :credit,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed balance after credit to match model" unless observed_state == after_state
      end
    },
    withdraw: {
      method: :debit,
      applicable_override: ->(state) { state > 0 },
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed balance after debit to match model" unless observed_state == after_state
      end
    }
  },
  verify_context: {
    state_reader: ->(sut) { sut.balance }
  }
}
