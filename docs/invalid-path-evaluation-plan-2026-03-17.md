# Invalid-Path Evaluation Plan

## Goal

Produce a small repeatable evaluation track that answers this narrower question:

- can the current generated scaffold recover invalid-path guard bugs through config-only edits?

This plan is intentionally separate from the valid-path 4-domain portfolio.

## Why This Track Exists

The fixed portfolio established that valid-path structural behavior is already practical and useful.
The remaining weak spot is not recurring update inference. It is that the default workflow stays on valid paths, so invalid-path guard mutants can survive unless the config intentionally drives them.

## Scope

Use the current four-domain invalid-path track:

- `partial_refund_remaining_capturable`
  - mutant: `refund_allows_over_refund`
- `payment_status_amounts`
  - mutant: `capture_amount_without_guard`
- `connection_pool`
  - mutant: `checkin_without_guard`
- `job_status_event_counters`
  - mutant: `retry_without_guard`

These cover both recurring invalid-path shapes we care about:

- out-of-range scalar arguments
- no-arg guard failures

## Fixed Workflow Per Domain

1. generate with:
   - `mise exec -- bin/spec_to_pbt INPUT.als --stateful --with-config -o generated`
2. edit only:
   - `*_pbt_config.rb`
   - `*_impl.rb`
3. do not edit:
   - `*_pbt.rb`
4. add config-only invalid-path driving:
   - `arguments_override` for out-of-range scalar args when needed
   - `guard_failure_policy: :raise` when the invalid path should surface an exception
5. run the generated scaffold against:
   - good implementation
   - previously surviving invalid-path mutant
6. record whether the mutant is now detected

## Metrics

Record these exact metrics per domain:

- `pbt_scaffold_edit_required`
- `config_only_invalid_path_green`
- `invalid_path_mutant_detected`
- `invalid_path_driver`
- `guard_failure_policy`

## Expected Interpretation

- if the track remains recoverable through config-only edits, keep invalid-path behavior off the generator fast path
- if recovery requires repeated non-obvious config patterns, improve config guidance and examples next
- only consider generator promotion if a recurring structural invalid-path pattern appears across more than two domains
