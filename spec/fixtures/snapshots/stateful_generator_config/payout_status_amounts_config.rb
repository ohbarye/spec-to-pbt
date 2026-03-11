# frozen_string_literal: true

# Regeneration-safe customization file for payout_status_amounts stateful scaffold.
# Edit this file to map spec command names to your real Ruby API and observed-state checks.
# This file is user-owned and should not be overwritten automatically.
# Suggested edit order:
# 1. sut_factory
# 2. command_mappings.*.method
# 3. verify_context.state_reader
# 4. verify_override
# 5. initial_state / next_state_override only when the inferred model state is not enough

PayoutStatusAmountsPbtConfig = {
  sut_factory: -> { PayoutStatusAmountsImpl.new },
  # initial_state: { status: 0, pending_amount: 0, paid_amount: 0 },
  command_mappings: {
    queue_amount: {
      method: :queue_amount,
      # arg_adapter: ->(args) { args }, # use when the Ruby API wants a different runtime argument shape
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result }, # use when the SUT result needs normalization before verify!
      # applicable_override: ->(state, args = nil) { true }, # use this for unsupported guards or richer domain preconditions
      # next_state_override: ->(state, args) { state }, # use this when invalid paths or derived state need a domain-specific model transition
      # guard_failure_policy: :no_op, # or :raise / :custom
      # Suggested failure/no-op handling: use :no_op for unchanged-state invalid calls, :raise for captured exceptions, or :custom with verify_override when the invalid path is domain-specific
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed state to match model\" unless observed_state == after_state } # use this for observed-state checks and lifecycle/business-rule-heavy invalid-path semantics
    },
    complete_amount: {
      method: :complete_amount,
      # arg_adapter: ->(args) { args }, # use when the Ruby API wants a different runtime argument shape
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result }, # use when the SUT result needs normalization before verify!
      # applicable_override: ->(state, args = nil) { true }, # use this for unsupported guards or richer domain preconditions
      # next_state_override: ->(state, args) { state }, # use this when invalid paths or derived state need a domain-specific model transition
      # guard_failure_policy: :no_op, # or :raise / :custom
      # Suggested failure/no-op handling: use :no_op for unchanged-state invalid calls, :raise for captured exceptions, or :custom with verify_override when the invalid path is domain-specific
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed state to match model\" unless observed_state == after_state } # use this for observed-state checks and lifecycle/business-rule-heavy invalid-path semantics
    },
    reset: {
      method: :reset,
      # arg_adapter: ->(args) { args }, # use when the Ruby API wants a different runtime argument shape
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result }, # use when the SUT result needs normalization before verify!
      # applicable_override: ->(state, args = nil) { true }, # use this for unsupported guards or richer domain preconditions
      # next_state_override: ->(state, args) { state }, # use this when invalid paths or derived state need a domain-specific model transition
      # guard_failure_policy: :no_op, # or :raise / :custom
      # Suggested failure/no-op handling: use :no_op for unchanged-state invalid calls, :raise for captured exceptions, or :custom with verify_override when the invalid path is domain-specific
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed state to match model\" unless observed_state == after_state } # use this for observed-state checks and lifecycle/business-rule-heavy invalid-path semantics
    }
  },
  verify_context: {
    state_reader: nil, # suggested: ->(sut) { { status: sut.status, pending_amount: sut.pending_amount, paid_amount: sut.paid_amount } }
  }
  # before_run: ->(sut) { },
  # after_run: ->(sut, result) { }
}