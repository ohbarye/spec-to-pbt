# Current State And Next Plan

## Purpose

This is the first document to read when resuming work on `spec-to-pbt`.

Use it for:

- current status
- what is stable
- what is open
- what to do next
- how to restart the work without re-discovering context

Use the roadmap for future direction and the retrospective for design history.

## Current Goal

The current goal is not a semantics-preserving Alloy-to-Ruby translator.

The goal is to make `spec-to-pbt` a practical generator for `pbt`-compatible
tests, especially stateful PBT scaffolds, such that:

- generated code runs
- generated code is safe and not misleading
- generated code is easy to finish by hand
- generated code can be regenerated without destroying durable customization

In short:

- input: formal-ish spec, currently Alloy
- output: practical PBT scaffold, especially for `Pbt.stateful`

## Current Position

The project is in the final practical-quality and domain-generalization phase.

Done or stable:

- rename to `spec-to-pbt` completed
- `--stateful` scaffold generation exists and is runnable
- frontend-neutral core + Alloy adapter are in place
- `pbt` `main` integration is established
- config-driven stateful workflow exists via `--with-config`
- full stateful regression stack exists:
  - unit specs
  - snapshot specs
  - contract specs
  - generated workflow integration specs
  - practical example workflows

Current testing baseline:

- `mise exec -- bundle exec rspec`
- current result: `242 examples, 0 failures`

Representative current workflow baseline:

- generated scaffold examples under `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/example/stateful/`
  are exercised by auto-discovered example-workflow integration coverage
- regenerated workflow coverage under:
  - `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/spec/integration/stateful_example_workflow_spec.rb`
  - `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/spec/integration/stateful_regenerated_workflow_spec.rb`

## Architecture Snapshot

The current structure is:

- frontend:
  - Alloy parser / adapter
- core:
  - frontend-neutral document model
- analyzer:
  - `StatefulPredicateAnalyzer` turns spec entities into scaffold facts
- generator:
  - stateless and stateful generators consume the core/analyzer output
- practical customization layer:
  - generated `*_pbt_config.rb`
- backend:
  - `pbt` `main`

Important architectural choices:

- generators should not depend directly on raw Alloy parser structs
- semantic inference belongs in the analyzer more than in rendering branches
- durable customization belongs in config, not in hand-edited generated scaffolds

## What Exists Today

Major supported capabilities:

- `bin/spec_to_pbt INPUT.als`
- `bin/spec_to_pbt INPUT.als --stateful`
- `bin/spec_to_pbt INPUT.als --stateful --with-config`
- config-driven `sut_factory`
- config-driven `initial_state`
- config-driven `next_state_override`
- config-driven `verify_override`
- config-driven `state_reader`
- config-driven `guard_failure_policy` for inferred guarded commands:
  - `:no_op`
  - `:raise`
  - `:custom` with `verify_override`
- config-driven method remapping and arg adaptation
- analyzer-driven `verify!` hints and safe executable checks
- generation of `arguments(state)` where inferable
- generation of `applicable?(state, args)` where inferable
- structured model state generation for several multi-field cases
- collection + projected scalar generation for append-only ledger/inventory-style patterns
- constant replacement / bounded replacement for reset-style structured scalar commands
- bounded replace-with-arg generation for companion-limit patterns such as rollout
- scalar equality-guard lifecycle transitions such as `status = 1 implies status' = 2`
- broad recurring-pattern coverage now exists across:
  - collection mutation
  - scalar mutation
  - paired counters / conservation
  - append-only projection
  - lifecycle status machines

## Representative Domains Covered

### Core structures

- stack
- queue
- sort
- bounded queue
- scalar workflow / counter-like cases
- cache size-preserving cases

### Financial domains

- bank account
- hold / capture / release
- transfer between accounts
- refund / reversal
- authorization expiry / void
- partial refund / remaining capturable
- ledger projection
- payment status lifecycle

### Software-general domains

- rate limiter
- connection pool
- feature flag rollout
- job queue retry / dead letter
- inventory projection
- job status lifecycle

## Most Important Decisions

### 1. Practical scaffold over perfect translation

The generator is intentionally a scaffold generator, not a proof of semantic
equivalence.

### 2. Analyzer-first quality improvements

Quality improvements were pushed into `StatefulPredicateAnalyzer` instead of
spreading more heuristics through the renderer.

### 3. Backend protocol escalation to `pbt`

When stateful usability hit protocol limits, the correct fix was to extend the
`pbt` command protocol rather than bury the problem in config hacks.

### 4. Config as regeneration-safe customization boundary

The stable workflow is:

- generated `*_pbt.rb`
- user-owned `*_pbt_config.rb`
- user-owned `*_impl.rb`

That separation is intentional and should be preserved.

## Known Boundaries

- failure / no-op semantics now have a basic taxonomy for inferred guarded commands:
  - reject by `applicable?`
  - invalid-but-unchanged via `guard_failure_policy: :no_op`
  - invalid-and-raises via `guard_failure_policy: :raise`
  - domain-owned invalid path via `guard_failure_policy: :custom` + `verify_override`
  but unsupported guards, lifecycle-specific rejection, and business-rule-heavy
  invalid paths are intentionally left config-owned
- some derived state still needs `next_state_override`, but append-only ledger-style
  collection + projected scalar patterns are now scaffolded directly and validated
  across both ledger and inventory domains
- Alloy is still the only public input frontend
- parsing is still regex-based, not full AST-based
- some domain patterns are practical only because config provides the final mile
- some constant-replacement or domain-capped transitions are still better served
  by config than by automatic inference

## Recommended Next Work

### 1. Keep the first-class boundary explicit and conservative

Why it matters:

- the generator is now strong enough that the main risk is overreaching into
  domain-specific semantics
- future work should not blur the line between safe inference and config-owned
  business rules

Success looks like:

- unsupported guards remain routed to `applicable_override`
- invalid paths beyond inferred guards remain routed to
  `guard_failure_policy: :custom`, `verify_override`, and
  `next_state_override`
- docs, generated comments, and examples stay aligned on that boundary

### 2. Expand recurring structural patterns only when a second domain confirms them

Why it matters:

- the project now has at least two confirmed recurring families:
  - append-only projection
  - lifecycle status transitions
- future generalization should follow the same bar: do not promote a pattern
  after only one domain example

Success looks like:

- new first-class behavior only lands after recurring evidence exists
- examples and regenerated workflows prove that the pattern is not domain-local

### 3. Keep the practical workflow regression net ahead of new heuristics

Why it matters:

- several strong example domains now exist
- the auto-discovered example workflow spec now makes it cheaper to keep that set
  honest as new practical examples are added

Success looks like:

- explicit identification of reusable patterns worth hardening
- stable regenerated workflows across the current domain set
- no regression in current practical workflows while keeping domain-specific
  logic config-owned

## How To Resume

Recommended restart sequence:

1. `git status --short --branch`
2. `mise exec -- bundle exec rspec`
3. if touching stateful generation, run targeted example/regenerated workflows:
   - `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/spec/integration/stateful_example_workflow_spec.rb`
   - `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/spec/integration/stateful_regenerated_workflow_spec.rb`
4. read this document first
5. read the roadmap second if deciding what to do next
6. read the retrospective only if you need the reasoning/history behind earlier
   decisions

## Reference Docs

- roadmap:
  - `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/docs/stateful-scaffold-roadmap-2026-03-04.md`
- retrospective:
  - `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/docs/stateful-scaffold-retrospective-2026-03-09.md`
- domain pattern catalog:
  - `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/docs/domain-pattern-catalog-2026-03-09.md`
- `pbt` protocol history:
  - `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/docs/pbt-stateful-api-feedback-2026-03-07.md`
