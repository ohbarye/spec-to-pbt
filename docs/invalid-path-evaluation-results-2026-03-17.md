# Invalid-Path Evaluation Results

## Summary

The config-only invalid-path track successfully recovered four guard mutants through config-only workflows.

This strengthens the current product boundary:

- valid-path structural workflows remain the default product path
- invalid-path semantics remain config-assisted / config-owned
- the next leverage point is config UX and evidence collection, not generator promotion

## Domain Results

| domain | invalid-path mutant | `*_pbt.rb` edited? | config-only green on good impl? | invalid-path mutant detected? | invalid-path driver |
| --- | --- | --- | --- | --- | --- |
| `partial_refund_remaining_capturable` | `refund_allows_over_refund` | no | yes | yes | `arguments_override` to generate `captured + 1` plus `guard_failure_policy: :raise` |
| `payment_status_amounts` | `capture_amount_without_guard` | no | yes | yes | `arguments_override` to generate `authorized_amount + 1` plus `guard_failure_policy: :raise` |
| `connection_pool` | `checkin_without_guard` | no | yes | yes | `guard_failure_policy: :raise` on `checkin` |
| `job_status_event_counters` | `retry_without_guard` | no | yes | yes | `guard_failure_policy: :raise` on `retry` |

## Interpretation

### Partial refund / remaining capturable

- the missing detection was not a generator blind spot in the valid transition
- it was enough to force an out-of-range refund amount through config
- `guard_failure_policy: :raise` then gave the scaffold the right oracle shape:
  - good implementation raises and keeps state unchanged
  - mutant silently mutates state and is caught by observed-state verification

### Connection pool / job status event counters

- no argument-generation change was required
- the generated workflow only needed permission to attempt the invalid command
- once `guard_failure_policy: :raise` was set, both mutants were detected without touching the scaffold

## Product Reading

This pass does not justify promoting new generator behavior.

What it does justify:

- stronger config comments around invalid-path driving
- a documented evaluation track for guard mutants
- examples that show when to use:
  - `arguments_override`
  - `guard_failure_policy`
  - `verify_context.state_reader`

## Recommendation

Keep the roadmap order conservative:

1. preserve the current valid-path generator boundary
2. improve config UX for invalid-path coverage
3. extend the invalid-path evaluation portfolio before considering promotion
