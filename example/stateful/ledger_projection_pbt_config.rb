# frozen_string_literal: true

LedgerProjectionPbtConfig = {
  sut_factory: -> { LedgerProjectionImpl.new },
  initial_state: { entries: [], balance: 0 },
  command_mappings: {
    post_credit: {
      method: :post_credit,
      model_arg_adapter: ->(args) { args.abs + 1 },
      next_state_override: ->(state, args) do
        delta = args.abs + 1
        { entries: state[:entries] + [delta], balance: state[:balance] + delta }
      end,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed ledger projection after credit to match model" unless observed_state == after_state
      end
    },
    post_debit: {
      method: :post_debit,
      model_arg_adapter: ->(args) { args.abs + 1 },
      next_state_override: ->(state, args) do
        delta = args.abs + 1
        { entries: state[:entries] + [-delta], balance: state[:balance] - delta }
      end,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed ledger projection after debit to match model" unless observed_state == after_state
      end
    }
  },
  verify_context: {
    state_reader: ->(sut) { { entries: sut.entries.dup, balance: sut.balance } }
  }
}
