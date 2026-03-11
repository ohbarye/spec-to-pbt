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

Examples prefer a local `../pbt` checkout. Override with `PBT_REPO_DIR` if needed.

```bash
ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec example/stateful/stack_pbt.rb
```

## What To Edit First

Edit in this order:

1. `*_pbt_config.rb`
2. `*_impl.rb`
3. `*_pbt.rb` only if config cannot express the workflow

Typical `*_pbt_config.rb` edits:

- `sut_factory`
- `command_mappings.*.method`
- `verify_context.state_reader`
- `verify_override`
- `initial_state`
- `next_state_override` only for richer model transitions
- `applicable_override` only for unsupported guards or richer preconditions

For current promotion boundaries and restart context:

- `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/docs/current-state-and-next-plan-2026-03-09.md`
- `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/docs/domain-pattern-catalog-2026-03-09.md`
