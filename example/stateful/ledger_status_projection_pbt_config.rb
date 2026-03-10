# frozen_string_literal: true

LedgerStatusProjectionPbtConfig = {
  sut_factory: -> { LedgerStatusProjectionImpl.new(status: 0, entries: [], balance: 0) },
  initial_state: { entries: [], status: 0, balance: 0 },
  command_mappings: {
    open: {
      method: :open,
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed ledger projection state after open to match model" unless observed_state == after_state
      end
    },
    post_amount: {
      method: :post_amount,
      model_arg_adapter: ->(args) { args.abs + 1 },
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed ledger projection state after post_amount to match model" unless observed_state == after_state
      end
    },
    close: {
      method: :close,
      guard_failure_policy: :raise,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed ledger projection state after close to match model" unless observed_state == after_state
      end
    }
  },
  verify_context: {
    state_reader: ->(sut) { { entries: sut.entries.dup, status: sut.status, balance: sut.balance } }
  }
}
