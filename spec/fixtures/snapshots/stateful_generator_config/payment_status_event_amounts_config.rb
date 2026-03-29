# frozen_string_literal: true

# Regeneration-safe customization file for payment_status_event_amounts stateful scaffold.
# Edit this file to map spec command names to your real Ruby API and observed-state checks.
# This file is user-owned and should not be overwritten automatically.
#
# Required fields (search for TODO(required) to find them):
#   sut_factory                   - how to create the system under test
#   command_mappings.*.method      - real Ruby method name for each command
#   verify_context.state_reader    - how to read observable state from the SUT
#
# Optional fields:
#   initial_state                  - override when inferred model baseline does not match SUT defaults
#   arg_adapter / model_arg_adapter - transform arguments for SUT or model
#   result_adapter                 - normalize SUT return values
#   arguments_override             - custom argument generator for invalid-path coverage
#   applicable_override            - override command applicability
#   next_state_override            - override model transition
#   verify_override                - override verification logic
#   guard_failure_policy           - :no_op / :raise / :custom for guard failures
#   before_run / after_run         - hooks around each command execution
#
# See docs/config-reference.md for full field documentation.

PaymentStatusEventAmountsPbtConfig = {
  sut_factory: -> { raise "TODO(required): replace with your SUT, e.g. YourClass.new" },
  # initial_state: { status: 0, captures: [], remaining_amount: 0, settled_amount: 0 }, # optional: set this when the inferred model baseline does not match your SUT defaults
  command_mappings: {
    open: {
      method: :open, # TODO(required): replace with real method name
      # arg_adapter: ->(args) { args }, # use when the Ruby API wants a different runtime argument shape
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result }, # use when the SUT result needs normalization before verify!
      # arguments_override: -> { Pbt.nil }, # optional 0-arity/1-arity generator override for invalid-path coverage or custom distributions
      # applicable_override: ->(state, args = nil) { true }, # use this for unsupported guards, richer domain preconditions, or to deliberately drive invalid calls
      # guard_failure_policy: :no_op, # or :raise / :custom
      # Suggested failure/no-op handling: use :no_op for unchanged-state invalid calls, :raise for captured exceptions, or :custom with verify_override when the invalid path is domain-specific
      # Note: leave inferred arguments(state) in place for valid-path coverage; add arguments_override only when you need out-of-range args or a custom invalid-path distribution.
      # Invalid-path starting point: set verify_context.state_reader first, then try guard_failure_policy: :raise to let the scaffold execute guard-failing calls.
      # next_state_override: ->(state, args) { state }, # use this when invalid paths or derived state need a domain-specific model transition
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed collection state to match model\" unless observed_state == after_state } # leave this commented out when state_reader already exposes the model-shaped observed state; enable it for custom postconditions or invalid-path semantics
    },
    settle_unit: {
      method: :settle_unit, # TODO(required): replace with real method name
      # arg_adapter: ->(args) { args }, # use when the Ruby API wants a different runtime argument shape
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result }, # use when the SUT result needs normalization before verify!
      # arguments_override: -> { Pbt.nil }, # optional 0-arity/1-arity generator override for invalid-path coverage or custom distributions
      # applicable_override: ->(state, args = nil) { true }, # use this for unsupported guards, richer domain preconditions, or to deliberately drive invalid calls
      # guard_failure_policy: :no_op, # or :raise / :custom
      # Suggested failure/no-op handling: use :no_op for unchanged-state invalid calls, :raise for captured exceptions, or :custom with verify_override when the invalid path is domain-specific
      # Note: leave inferred arguments(state) in place for valid-path coverage; add arguments_override only when you need out-of-range args or a custom invalid-path distribution.
      # Invalid-path starting point: set verify_context.state_reader first, then try guard_failure_policy: :raise to let the scaffold execute guard-failing calls.
      # next_state_override: ->(state, args) { state }, # use this when invalid paths or derived state need a domain-specific model transition
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed collection state to match model\" unless observed_state == after_state } # leave this commented out when state_reader already exposes the model-shaped observed state; enable it for custom postconditions or invalid-path semantics
    },
    close: {
      method: :close, # TODO(required): replace with real method name
      # arg_adapter: ->(args) { args }, # use when the Ruby API wants a different runtime argument shape
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result }, # use when the SUT result needs normalization before verify!
      # arguments_override: -> { Pbt.nil }, # optional 0-arity/1-arity generator override for invalid-path coverage or custom distributions
      # applicable_override: ->(state, args = nil) { true }, # use this for unsupported guards, richer domain preconditions, or to deliberately drive invalid calls
      # guard_failure_policy: :no_op, # or :raise / :custom
      # Suggested failure/no-op handling: use :no_op for unchanged-state invalid calls, :raise for captured exceptions, or :custom with verify_override when the invalid path is domain-specific
      # Note: leave inferred arguments(state) in place for valid-path coverage; add arguments_override only when you need out-of-range args or a custom invalid-path distribution.
      # Invalid-path starting point: set verify_context.state_reader first, then try guard_failure_policy: :raise to let the scaffold execute guard-failing calls.
      # next_state_override: ->(state, args) { state }, # use this when invalid paths or derived state need a domain-specific model transition
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed collection state to match model\" unless observed_state == after_state } # leave this commented out when state_reader already exposes the model-shaped observed state; enable it for custom postconditions or invalid-path semantics
    }
  },
  verify_context: {
    state_reader: nil, # TODO(required): suggested: ->(sut) { { captures: sut.captures.dup, status: sut.status, remaining_amount: sut.remaining_amount, settled_amount: sut.settled_amount } } — without this, SUT state is not compared against the model
  }
  # before_run: ->(sut) { },
  # after_run: ->(sut, result) { }
}