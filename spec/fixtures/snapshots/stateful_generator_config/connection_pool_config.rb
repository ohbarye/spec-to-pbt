# frozen_string_literal: true

# Regeneration-safe customization file for connection_pool stateful scaffold.
# Edit this file to map spec command names to your real Ruby API and observed-state checks.
# This file is user-owned and should not be overwritten automatically.
# Suggested edit order:
# 1. sut_factory
# 2. initial_state only when the inferred model baseline does not match your SUT defaults
# 3. command_mappings.*.method
# 4. verify_context.state_reader
# 5. leave verify_override unset when observed state should directly match the model
# 6. arguments_override / applicable_override / guard_failure_policy for invalid-path coverage or richer generators
# 7. next_state_override only when the inferred model transition is not enough
# Tip: for invalid-path work, wire verify_context.state_reader before changing command-level overrides so silent SUT mutations stay visible.

ConnectionPoolPbtConfig = {
  sut_factory: -> { ConnectionPoolImpl.new },
  # initial_state: { available: 0, checked_out: 0, capacity: 3 }, # set this when the inferred model baseline does not match your SUT defaults
  command_mappings: {
    checkout: {
      method: :checkout,
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
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed state to match model\" unless observed_state == after_state } # leave this commented out when state_reader already exposes the model-shaped observed state; enable it for custom postconditions or invalid-path semantics
    },
    checkin: {
      method: :checkin,
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
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed state to match model\" unless observed_state == after_state } # leave this commented out when state_reader already exposes the model-shaped observed state; enable it for custom postconditions or invalid-path semantics
    }
  },
  verify_context: {
    state_reader: nil, # suggested: ->(sut) { { available: sut.available, checked_out: sut.checked_out, capacity: sut.capacity } }; configure this when observed-state checks should be compared against the model
  }
  # before_run: ->(sut) { },
  # after_run: ->(sut, result) { }
}