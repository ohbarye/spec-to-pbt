# frozen_string_literal: true

# Regeneration-safe customization file for transfer_between_accounts stateful scaffold.
# Edit this file to map spec command names to your real Ruby API and observed-state checks.
# This file is user-owned and should not be overwritten automatically.
# Suggested edit order:
# 1. sut_factory
# 2. command_mappings.*.method
# 3. verify_context.state_reader
# 4. verify_override
# 5. initial_state / next_state_override only when the inferred model state is not enough
# 6. applicable_override / guard_failure_policy when guard handling or invalid-path behavior matters

TransferBetweenAccountsPbtConfig = {
  sut_factory: -> { TransferBetweenAccountsImpl.new },
  # initial_state: { source_balance: 0, target_balance: 0 }, # set this when the inferred model baseline does not match your SUT defaults
  command_mappings: {
    transfer: {
      method: :transfer,
      # Suggested real API methods: :move_funds, :transfer_amount, :post_transfer
      # arg_adapter: ->(args) { args }, # use when the Ruby API wants a different runtime argument shape
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result }, # use when the SUT result needs normalization before verify!
      # applicable_override: ->(state, args = nil) { true }, # use this for unsupported guards, richer domain preconditions, or no-arg invalid-path coverage
      # next_state_override: ->(state, args) { state }, # use this when invalid paths or derived state need a domain-specific model transition
      # guard_failure_policy: :no_op, # or :raise / :custom
      # Suggested failure/no-op handling: use :no_op for unchanged-state invalid calls, :raise for captured exceptions, or :custom with verify_override when the invalid path is domain-specific
      # Note: inferred arguments(state) usually stay on valid paths. Keep richer invalid-path checks in config when they depend on out-of-range args or mixed guards.
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed account balances to match model\" unless observed_state == after_state } # use this for observed-state checks and lifecycle/business-rule-heavy invalid-path semantics
    }
  },
  verify_context: {
    state_reader: nil, # suggested: ->(sut) { { source_balance: sut.source_balance, target_balance: sut.target_balance } }; configure this when verify_override needs observed-state checks against the SUT
  }
  # before_run: ->(sut) { },
  # after_run: ->(sut, result) { }
}