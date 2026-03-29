# frozen_string_literal: true

# Regeneration-safe customization file for weak stateful scaffold.
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

WeakPbtConfig = {
  sut_factory: -> { raise "TODO(required): replace with your SUT, e.g. YourClass.new" },
  # initial_state: [], # optional: set this when the inferred model baseline does not match your SUT defaults
  command_mappings: {
  },
  verify_context: {
    state_reader: nil, # TODO(required): suggested: expose a snapshot/reader for the model state — without this, SUT state is not compared against the model
  }
  # before_run: ->(sut) { },
  # after_run: ->(sut, result) { }
}