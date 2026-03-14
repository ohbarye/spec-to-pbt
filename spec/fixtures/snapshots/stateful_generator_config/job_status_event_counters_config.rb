# frozen_string_literal: true

# Regeneration-safe customization file for job_status_event_counters stateful scaffold.
# Edit this file to map spec command names to your real Ruby API and observed-state checks.
# This file is user-owned and should not be overwritten automatically.
# Suggested edit order:
# 1. sut_factory
# 2. command_mappings.*.method
# 3. verify_context.state_reader
# 4. verify_override
# 5. initial_state / next_state_override only when the inferred model state is not enough
# 6. applicable_override / guard_failure_policy when guard handling or invalid-path behavior matters

JobStatusEventCountersPbtConfig = {
  sut_factory: -> { JobStatusEventCountersImpl.new },
  # initial_state: { status: 0, events: [], retry_budget: 0, retry_count: 0 }, # set this when the inferred model baseline does not match your SUT defaults
  command_mappings: {
    activate: {
      method: :activate,
      # arg_adapter: ->(args) { args }, # use when the Ruby API wants a different runtime argument shape
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result }, # use when the SUT result needs normalization before verify!
      # applicable_override: ->(state, args = nil) { true }, # use this for unsupported guards, richer domain preconditions, or no-arg invalid-path coverage
      # next_state_override: ->(state, args) { state }, # use this when invalid paths or derived state need a domain-specific model transition
      # guard_failure_policy: :no_op, # or :raise / :custom
      # Suggested failure/no-op handling: use :no_op for unchanged-state invalid calls, :raise for captured exceptions, or :custom with verify_override when the invalid path is domain-specific
      # Note: inferred arguments(state) usually stay on valid paths. Keep richer invalid-path checks in config when they depend on out-of-range args or mixed guards.
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed collection state to match model\" unless observed_state == after_state } # use this for observed-state checks and lifecycle/business-rule-heavy invalid-path semantics
    },
    retry: {
      method: :retry,
      # arg_adapter: ->(args) { args }, # use when the Ruby API wants a different runtime argument shape
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result }, # use when the SUT result needs normalization before verify!
      # applicable_override: ->(state, args = nil) { true }, # use this for unsupported guards, richer domain preconditions, or no-arg invalid-path coverage
      # next_state_override: ->(state, args) { state }, # use this when invalid paths or derived state need a domain-specific model transition
      # guard_failure_policy: :no_op, # or :raise / :custom
      # Suggested failure/no-op handling: use :no_op for unchanged-state invalid calls, :raise for captured exceptions, or :custom with verify_override when the invalid path is domain-specific
      # Note: inferred arguments(state) usually stay on valid paths. Keep richer invalid-path checks in config when they depend on out-of-range args or mixed guards.
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed collection state to match model\" unless observed_state == after_state } # use this for observed-state checks and lifecycle/business-rule-heavy invalid-path semantics
    },
    deactivate: {
      method: :deactivate,
      # arg_adapter: ->(args) { args }, # use when the Ruby API wants a different runtime argument shape
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result }, # use when the SUT result needs normalization before verify!
      # applicable_override: ->(state, args = nil) { true }, # use this for unsupported guards, richer domain preconditions, or no-arg invalid-path coverage
      # next_state_override: ->(state, args) { state }, # use this when invalid paths or derived state need a domain-specific model transition
      # guard_failure_policy: :no_op, # or :raise / :custom
      # Suggested failure/no-op handling: use :no_op for unchanged-state invalid calls, :raise for captured exceptions, or :custom with verify_override when the invalid path is domain-specific
      # Note: inferred arguments(state) usually stay on valid paths. Keep richer invalid-path checks in config when they depend on out-of-range args or mixed guards.
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed collection state to match model\" unless observed_state == after_state } # use this for observed-state checks and lifecycle/business-rule-heavy invalid-path semantics
    }
  },
  verify_context: {
    state_reader: nil, # suggested: ->(sut) { { events: sut.events.dup, status: sut.status, retry_budget: sut.retry_budget, retry_count: sut.retry_count } }; configure this when verify_override needs observed-state checks against the SUT
  }
  # before_run: ->(sut) { },
  # after_run: ->(sut, result) { }
}