# Portfolio Evaluation Results

## Domain Evidence

| domain | recurring pattern family | `*_pbt.rb` edits required | config-only green | files_user_edited | friction_categories | mutants_detected / total |
| --- | --- | --- | --- | --- | --- | --- |
| `partial_refund_remaining_capturable` | paired amount movement + guarded structured scalar state | no | yes | `config`, `impl` | `model_state_shape`, `observed_state_verification` | `2 / 3` |
| `ledger_projection` | append-only projection | no | yes | `config`, `impl` | `observed_state_verification`, `arg_normalization` | `3 / 3` |
| `job_status_event_counters` | status-gated event projection + counters | no | yes | `config`, `impl` | `model_state_shape`, `observed_state_verification`, `unsupported_guard`, `invalid_path_semantics` | `3 / 3` |
| `connection_pool` | bounded paired counters | no | yes | `config`, `impl` | `model_state_shape`, `observed_state_verification` | `2 / 3` |

## Mutant Matrices

### Partial refund / remaining capturable

| mutant_id | defect_type | detected | reason if not detected |
| --- | --- | --- | --- |
| `refund_wrong_field` | update bug | yes | |
| `refund_allows_over_refund` | guard bug | no | generated workflow never exercises invalid refund amounts because `arguments(state)` stays within captured balance |
| `refund_breaks_conservation` | preservation bug | yes | |

### Ledger projection

| mutant_id | defect_type | detected | reason if not detected |
| --- | --- | --- | --- |
| `credit_without_balance_update` | projection bug | yes | |
| `debit_wrong_direction` | update bug | yes | |
| `credit_wrong_event_append` | append bug | yes | |

### Job status event counters

| mutant_id | defect_type | detected | reason if not detected |
| --- | --- | --- | --- |
| `retry_without_event_append` | projection bug | yes | |
| `retry_without_budget_consumption` | update bug | yes | |
| `deactivate_keeps_status` | lifecycle bug | yes | |

### Connection pool

| mutant_id | defect_type | detected | reason if not detected |
| --- | --- | --- | --- |
| `checkout_wrong_counter` | update bug | yes | |
| `checkin_without_guard` | guard bug | no | generated workflow does not drive invalid `checkin` calls because inferred applicability keeps the command on valid paths |
| `checkout_breaks_capacity_relation` | preservation bug | yes | |

## Cross-Domain Summary

| recurring family | practicality status | green via config/impl-only | defect detection evidence |
| --- | --- | --- | --- |
| bounded paired counters | first-class + config-assisted observed-state wiring | yes | mixed |
| append-only projection | first-class + config-assisted observed-state wiring | yes | strong |
| paired amount movement | first-class update shape + config-assisted observed-state wiring | yes | mixed |
| status-gated counters / lifecycle | config-assisted | yes | strong |
| invalid-path guard semantics | config-owned | yes | weak when invalid paths are not exercised by the generated valid workflow |

## Undetected Mutant Review

| domain | mutant_id | uncovered family | classification | current handling |
| --- | --- | --- | --- | --- |
| `partial_refund_remaining_capturable` | `refund_allows_over_refund` | invalid refund path | `invalid-path valid-only workflow` | keep config-owned; use config comments and `guard_failure_policy` / `verify_override` guidance rather than generator promotion |
| `connection_pool` | `checkin_without_guard` | invalid checkin path | `invalid-path valid-only workflow` | keep config-owned; use config comments and `applicable_override` / `guard_failure_policy` guidance rather than generator promotion |

Interpretation:

- both undetected mutants are in the same family
- neither is a mixed-guard miss; both are valid-only workflow gaps
- this pass does not justify generator promotion because the missing behavior depends on intentionally driving invalid paths, not on a structurally missing valid-path update

## Product Actions From This Pass

- improve config comments for:
  - `initial_state`
  - `verify_context.state_reader`
  - `applicable_override`
  - `guard_failure_policy`
- keep invalid-path and mixed-guard semantics on the config-assisted / config-owned side
- do not promote new generator behavior from this pass
- treat future invalid-path mutants as a separate evidence track from valid-path structural bugs

## Interpretation

- **Viability:** all 4 domains reached green without editing generated `*_pbt.rb`
- **Practicality:** users only needed config + implementation edits, mainly for initial state, API wiring, observed-state verification, and unsupported/mixed guards
- **Usefulness:** recurring structural families already detect many realistic update/projection bugs
- **Boundary evidence:** invalid-path and mixed-guard semantics remain the main uncovered area, which is consistent with the current first-class / config-assisted / config-owned boundary
