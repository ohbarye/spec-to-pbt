# Quint Dual-Domain Comparison Note

This note records the current comparison-ready Quint coverage for two stateful domains:

- `feature_flag_rollout`
- `job_queue_retry_dead_letter`

## Why these two domains

These domains are intentionally practical without being too large:

- `feature_flag_rollout` exercises bounded scalar replacement and field-to-field replacement
- `job_queue_retry_dead_letter` exercises multi-command counter workflows with guarded transitions

Together they cover two recurring stateful families that are already important on the Alloy side.

## What parity means here

Parity in this pass means **behavioral parity**, not text-level translation parity.

The target is:

- same command family
- same main state shape
- same primary guards
- same primary state updates
- same basic invariant / boundedness style property

The Quint source is allowed to look natural for Quint even when it is not a literal transliteration of the Alloy source.

## Current goal

The goal of this pass is **generate parity**:

- both frontends should produce stateful scaffold / config output for the same domain
- adapter, generator, CLI, and snapshot tests should compare those domains inside this repo

The current non-goal is **green workflow parity** on the Quint side.
That remains a later step after generate parity is stable.
