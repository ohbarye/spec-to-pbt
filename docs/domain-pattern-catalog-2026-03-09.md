# Domain Pattern Catalog

## Purpose

This document inventories the recurring stateful-domain patterns currently
covered by `spec-to-pbt` and classifies them into:

- patterns now treated as first-class generator behavior
- patterns that are practical but still rely on config/customization
- patterns that should probably remain config-owned

Use this document when deciding what to generalize next.

## Current Classification

### Tier 1: First-Class Or Near First-Class In Generator

These are patterns where the generator now produces a practical default scaffold
without requiring deep manual edits.

#### 1. Collection append / remove workflows

Representative domains:

- stack
- queue
- bounded queue
- membership queue

Current generator behavior:

- command extraction is stable
- collection model state is generated
- `next_state` is concrete for append / pop / dequeue
- safe `verify!` checks cover:
  - size change
  - newest element ordering where safe
  - membership-after-append where safe
  - pop/dequeue result checks

Remaining gaps:

- richer queue semantics beyond safe local checks
- some bounded-resource failure behavior still needs policy/config

#### 2. Scalar increment / decrement / replace

Representative domains:

- workflow scalar
- bank account
- wallet with limit
- scalar replace arg
- scalar preserve value

Current generator behavior:

- scalar initial state defaults are practical
- `arguments(state)` and `applicable?(state, args)` are generated where inferable
- `next_state` is concrete for:
  - `+1`
  - `-1`
  - arg-based increment/decrement
  - replace-with-arg
  - replace-from-field
- safe `verify!` checks cover:
  - increment/decrement equality
  - replace-value equality
  - preserve-value equality
  - non-negative scalar invariants where inferred

Remaining gaps:

- richer domain guards still sometimes need config
- constant replacement is still uneven

#### 3. Multi-field scalar conservation / paired updates

Representative domains:

- transfer between accounts
- hold / capture / release
- refund / reversal
- partial refund / remaining capturable
- connection pool

Current generator behavior:

- structured scalar hash models are generated
- paired increment/decrement updates are rendered into concrete `next_state`
- safe `verify!` checks cover:
  - per-field updates
  - total-preservation checks where structurally safe

Remaining gaps:

- domain-specific failure semantics
- some lifecycle-specific rules still need overrides

#### 4. Guard-aware invalid-path handling

Representative domains:

- withdraw / debit
- bounded queue enqueue
- pool checkout/checkin
- hold/capture/release

Current generator behavior:

- inferred guards drive `applicable?`
- config can now set `guard_failure_policy: :no_op | :raise`
- scaffold can automatically verify:
  - unchanged model state on guard failure
  - unchanged observed state on guard failure
  - captured exception on guard failure when configured as `:raise`

Remaining gaps:

- richer reject/no-op semantics are still partial
- unsupported guards still fall back to config/custom logic

#### 5. Append-only collection + projected scalar

Representative domains:

- ledger projection

Current generator behavior:

- collection state is chosen as the primary model target
- structured collection model is generated
- companion scalar projection updates are emitted in `next_state`
- safe `verify!` checks cover:
  - appended projected entry shape
  - projected scalar balance update

Remaining gaps:

- broader derived-state relationships are not yet generalized beyond this shape

### Tier 2: Practical But Still Config-Assisted

These patterns work in practice, but the last mile still relies on
`*_pbt_config.rb`.

#### 1. API naming / argument normalization

Representative domains:

- almost all real Ruby targets

Why config remains appropriate:

- method names are user-domain specific
- `arg_adapter`, `model_arg_adapter`, and `result_adapter` are durable
  customization rather than inference targets

#### 2. Observed state projection

Representative domains:

- transfer
- hold/capture/release
- refund/reversal
- ledger projection
- job queue retry / dead letter

Why config remains appropriate:

- real SUT readers vary widely
- `state_reader` and `verify_override` are the right boundary for this

#### 3. Constant-reset / domain-reset commands

Representative domains:

- feature flag disable -> rollout `0`
- some rate limiter reset variants

Why this is not fully first-class yet:

- some reset targets are obvious constants
- others are domain-owned semantics
- current generator can handle some cases, but not uniformly enough to promote
  as a general rule

#### 4. Rich failure/no-op semantics

Representative domains:

- payment authorization lifecycle
- refund/reversal
- transfer failure
- job queue dead-letter movement

Why config still matters:

- the difference between reject, no-op, and error is domain-owned
- `guard_failure_policy` only covers the safe common subset

### Tier 3: Likely To Stay Config-Owned

These are patterns where automatic inference is probably not worth the risk.

#### 1. Exact SUT wiring

- constructor shape
- service object orchestration
- repository / gateway setup
- domain-specific adapters

#### 2. Domain-specific postconditions beyond safe structure

- business-rule-heavy assertions
- side effects outside the model state
- event emission / persistence behavior

#### 3. Semantic choices not explicit in the spec shape

- whether invalid calls should be possible at all
- whether a failed call should be represented as error, result object, or no-op
- what the externally observed state should expose

## Pattern Inventory By Domain

### Financial

- bank account:
  - scalar increment/decrement
  - arg-aware withdraw guard
- hold / capture / release:
  - multi-field scalar conservation
  - guard-aware invalid paths
- transfer between accounts:
  - paired balances
  - total-preservation
- refund / reversal:
  - settlement lifecycle with partial invalid-path semantics
- authorization expiry / void:
  - release-style paired updates
- partial refund / remaining capturable:
  - three-field payment state
- ledger projection:
  - append-only log + projected scalar

### Software-General

- rate limiter:
  - structured scalar capacity/reset
- connection pool:
  - paired counters + guards
- feature flag rollout:
  - bounded arg replacement + disable reset
- job queue retry / dead letter:
  - lifecycle counters + observed-state verification

## Recommended Next Generalization Targets

### 1. Constant replacement / bounded replacement

Why next:

- shows up in feature flag rollout and reset-like domains
- smaller step than broader lifecycle semantics

Success looks like:

- more commands can generate concrete `next_state` without `next_state_override`
- no speculative domain behavior is introduced

### 2. Broader derived-state relationships

Why next:

- ledger-style projection is now partially first-class
- similar patterns may exist in queue/job/payment projections

Success looks like:

- analyzer facts explicitly model projection relationships
- fewer projection-specific overrides in config

### 3. Lifecycle/failure semantics taxonomy

Why next:

- many real domains now converge on the same unresolved question
- current `guard_failure_policy` is useful but intentionally narrow

Success looks like:

- explicit guidance on what stays generator-owned vs config-owned
- less ambiguity in invalid-path scaffolds

## What Not To Generalize Prematurely

- arbitrary API method remapping
- precise observed-state readers
- domain-specific business assertions
- speculative no-op vs reject semantics without strong evidence

These belong in config unless a repeated structural pattern becomes undeniable.

## How To Use This Catalog

When a new example domain is added:

1. classify it against the existing pattern tiers
2. identify whether its pain is:
   - analyzer gap
   - generator gap
   - config ergonomics gap
   - backend protocol gap
3. only promote a pattern to first-class when it appears in multiple domains and
   the generated behavior is safe
