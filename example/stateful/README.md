# Stateful Example Workflows

This directory contains practical `spec -> generate -> config/impl edit -> green`
examples for `spec-to-pbt`.

## Recommended Starting Order

### Core

- `stack`
  - smallest runnable stateful scaffold
- `bounded_queue`
  - collection state plus inferred capacity guard

### Financial

- `bank_account`
  - scalar balance plus amount-aware commands
- `hold_capture_release`
  - multi-field financial state
- `transfer_between_accounts`
  - total-preservation workflow

### Software-general

- `rate_limiter`
  - structured scalar state and reset-to-capacity
- `connection_pool`
  - paired counters and bounded resource checks
- `feature_flag_rollout`
  - bounded replacement and lifecycle-like transitions

## Advanced Families

### Projection

- `ledger_projection`
- `inventory_projection`
- `ledger_status_projection`
- `inventory_status_projection`
- `payment_status_event_amounts`
- `job_status_event_counters`

### Lifecycle

- `payment_status_lifecycle`
- `job_status_lifecycle`
- `authorization_expiry_void`
- `partial_refund_remaining_capturable`

## Running An Example

Examples use the bundled `pbt` gem by default. Override with `PBT_REPO_DIR` if needed.
Examples assume `pbt >= 0.6.0` with `Pbt.stateful`.
By default they use the bundled `pbt` gem; for repo development only, you can point them at a local checkout with `PBT_REPO_DIR=/path/to/pbt`.

```bash
ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec example/stateful/stack_pbt.rb
```

## What To Edit First

Edit in this order:

1. `*_pbt_config.rb`
2. `*_impl.rb`
3. `*_pbt.rb` only if config cannot express the workflow

Two practical rules from the current evaluation baseline:

1. treat `verify_context.state_reader` as the default place to connect model state to observed SUT state
2. treat invalid-path and mixed-guard behavior as config work first:
   - `applicable_override` for unsupported or richer preconditions
   - `guard_failure_policy` for simple inferred invalid-path behavior
   - `verify_override` for observed-state checks and domain-specific invalid-path contracts

Typical `*_pbt_config.rb` edits:

- `sut_factory`
- `command_mappings.*.method`
- `verify_context.state_reader`
- leave `verify_override` unset first when `state_reader` already returns the model-shaped observed state
- `arguments_override` when you need invalid-path coverage or a custom generator distribution
- `verify_override` for domain-specific postconditions or invalid-path semantics
- `initial_state`
- `next_state_override` only for richer model transitions
- `applicable_override` only for unsupported guards or richer preconditions

If you want a representative complex path, start from:

- `partial_refund_remaining_capturable`
  - guarded multi-field financial state
- `job_status_event_counters`
  - status-gated counters plus invalid-path boundary
- `ledger_projection`
  - append-only projection with strong valid-path coverage
- `connection_pool`
  - bounded paired counters with an invalid checkin boundary

For current promotion boundaries and restart context:

- `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/docs/current-state-and-next-plan-2026-03-09.md`
- `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/docs/domain-pattern-catalog-2026-03-09.md`
- `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/docs/portfolio-evaluation-results-2026-03-14.md`
