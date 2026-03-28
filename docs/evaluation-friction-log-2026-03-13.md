# Evaluation Friction Log

This file records facts from the 2026-03-13 product evaluation pass.

## Trial: partial_refund_remaining_capturable

| domain | fixture | command_or_pattern | file_touched | user_action_required | why_generation_was_insufficient | category | recurring_elsewhere | candidate_action | final_decision |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| financial | `partial_refund_remaining_capturable.als` | stateful runtime setup | generated execution command | run with `RUBYOPT=-I/path/to/pbt/lib` in this repo workspace | bundled `pbt` did not provide `Pbt.stateful`, so the scaffold failed before domain logic ran | `documentation_gap` | `job_status_event_counters` | `improve_comment_or_docs` | `improve_comment_or_docs` |
| financial | `partial_refund_remaining_capturable.als` | initial state baseline | `*_pbt_config.rb` | set `initial_state` to `{ authorized: 20, captured: 0, refunded: 0 }` | generated zero baseline was valid but not useful for exercising refund flow | `model_state_shape` | `job_status_event_counters` | `leave_in_config` | `leave_in_config` |
| financial | `partial_refund_remaining_capturable.als` | observed payment-state verification | `*_pbt_config.rb` | add `verify_context.state_reader` and `verify_override` for both commands | scaffold cannot infer the concrete SUT state reader or the exact observed-state contract | `observed_state_verification` | `job_status_event_counters` | `leave_in_config` | `leave_in_config` |

## Trial: job_status_event_counters

| domain | fixture | command_or_pattern | file_touched | user_action_required | why_generation_was_insufficient | category | recurring_elsewhere | candidate_action | final_decision |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| software-general | `job_status_event_counters.als` | stateful runtime setup | generated execution command | run with `RUBYOPT=-I/path/to/pbt/lib` in this repo workspace | bundled `pbt` did not provide `Pbt.stateful`, so the scaffold failed before domain logic ran | `documentation_gap` | `partial_refund_remaining_capturable` | `improve_comment_or_docs` | `improve_comment_or_docs` |
| software-general | `job_status_event_counters.als` | initial state baseline | `*_pbt_config.rb` | set `initial_state` to `{ events: [], status: 0, retry_budget: 3, retry_count: 0 }` | generated zero baseline was valid but not useful for the retry path because no retry budget existed | `model_state_shape` | `partial_refund_remaining_capturable` | `leave_in_config` | `leave_in_config` |
| software-general | `job_status_event_counters.als` | observed job-state verification | `*_pbt_config.rb` | add `verify_context.state_reader` and `verify_override` for all commands | scaffold cannot infer the concrete SUT state reader or the exact observed-state contract | `observed_state_verification` | `partial_refund_remaining_capturable` | `leave_in_config` | `leave_in_config` |
| software-general | `job_status_event_counters.als` | mixed status + scalar guard | `*_pbt_config.rb` | add `applicable_override` for `retry` | guard requires `status == 1 && retry_budget > 0`, which remains outside the current safe first-class boundary | `unsupported_guard` | `no` | `leave_in_config` | `leave_in_config` |
| software-general | `job_status_event_counters.als` | invalid transition handling | `*_pbt_config.rb` | set `guard_failure_policy: :raise` for `activate` and `deactivate` | domain expects invalid transitions to raise; this remains config-owned as a lifecycle-specific invalid path choice | `invalid_path_semantics` | `no` | `leave_in_config` | `leave_in_config` |

## Promotion Decision Summary

### Promote now

- none

### Keep config-assisted

- initial model-state baselines that make a domain meaningfully exercise the intended commands
- observed-state verification wiring via `verify_context.state_reader` and `verify_override`

### Keep config-owned

- mixed guards such as `status == constant && scalar > 0`
- lifecycle-specific invalid-path semantics such as choosing `:raise` for invalid transitions

## Notes

- The only recurring cross-domain friction in this pass that warranted an immediate product change was documentation and CLI guidance for stateful runtime setup.
- No parser or Alloy frontend work was implicated by this pass.
