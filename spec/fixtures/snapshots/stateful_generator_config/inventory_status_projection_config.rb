# frozen_string_literal: true

# Regeneration-safe customization file for inventory_status_projection stateful scaffold.
# Edit this file to map spec command names to your real Ruby API.
# This file is user-owned and should not be overwritten automatically.

InventoryStatusProjectionPbtConfig = {
  sut_factory: -> { InventoryStatusProjectionImpl.new },
  # initial_state: { status: 0, movements: [], stock: 0 },
  command_mappings: {
    activate: {
      method: :activate,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true }, # use this for unsupported guards or richer domain preconditions
      # next_state_override: ->(state, args) { state }, # use this when invalid paths or derived state need a domain-specific model transition
      # guard_failure_policy: :no_op, # or :raise / :custom
      # Suggested failure/no-op handling: use :no_op for unchanged-state invalid calls, :raise for captured exceptions, or :custom with verify_override when the invalid path is domain-specific
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed collection state to match model\" unless observed_state == after_state } # use this for observed-state checks and lifecycle/business-rule-heavy invalid-path semantics
    },
    receive: {
      method: :receive,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true }, # use this for unsupported guards or richer domain preconditions
      # next_state_override: ->(state, args) { state }, # use this when invalid paths or derived state need a domain-specific model transition
      # guard_failure_policy: :no_op, # or :raise / :custom
      # Suggested failure/no-op handling: use :no_op for unchanged-state invalid calls, :raise for captured exceptions, or :custom with verify_override when the invalid path is domain-specific
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed collection state to match model\" unless observed_state == after_state } # use this for observed-state checks and lifecycle/business-rule-heavy invalid-path semantics
    },
    deactivate: {
      method: :deactivate,
      # arg_adapter: ->(args) { args },
      # model_arg_adapter: ->(args) { args }
      # result_adapter: ->(result) { result },
      # applicable_override: ->(state, args = nil) { true }, # use this for unsupported guards or richer domain preconditions
      # next_state_override: ->(state, args) { state }, # use this when invalid paths or derived state need a domain-specific model transition
      # guard_failure_policy: :no_op, # or :raise / :custom
      # Suggested failure/no-op handling: use :no_op for unchanged-state invalid calls, :raise for captured exceptions, or :custom with verify_override when the invalid path is domain-specific
      # verify_override: ->(after_state:, observed_state:, **) { raise \"Expected observed collection state to match model\" unless observed_state == after_state } # use this for observed-state checks and lifecycle/business-rule-heavy invalid-path semantics
    }
  },
  verify_context: {
    state_reader: nil, # suggested: ->(sut) { { movements: sut.movements.dup, status: sut.status, stock: sut.stock } }
  }
  # before_run: ->(sut) { },
  # after_run: ->(sut, result) { }
}