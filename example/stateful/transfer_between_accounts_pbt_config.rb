# frozen_string_literal: true

TransferBetweenAccountsPbtConfig = {
  sut_factory: -> { TransferBetweenAccountsImpl.new(source_balance: 10, target_balance: 0) },
  command_mappings: {
    transfer: {
      method: :transfer,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed account balances after transfer to match model" unless observed_state == after_state
      end
    }
  },
  verify_context: {
    state_reader: ->(sut) { { source_balance: sut.source_balance, target_balance: sut.target_balance } }
  }
}
