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
- current result: `217 examples, 0 failures`

Representative current workflow baseline:

- generated scaffold examples under `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/example/stateful/`
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
- config-driven method remapping and arg adaptation
- analyzer-driven `verify!` hints and safe executable checks
- generation of `arguments(state)` where inferable
- generation of `applicable?(state, args)` where inferable
- structured model state generation for several multi-field cases

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

### Software-general domains

- rate limiter
- connection pool
- feature flag rollout
- job queue retry / dead letter

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

- failure / no-op semantics are only partly automated
- derived state often still needs `next_state_override`
- Alloy is still the only public input frontend
- parsing is still regex-based, not full AST-based
- some domain patterns are practical only because config provides the final mile
- some constant-replacement or domain-capped transitions are still better served
  by config than by automatic inference

## Recommended Next Work

### 1. Failure / no-op semantics

Why it matters:

- many practical domains care as much about invalid-call behavior as successful
  transitions
- finance and lifecycle workflows especially depend on this

Success looks like:

- clearer policy for reject vs no-op vs unchanged-state verification
- safe automation where semantics are genuinely inferable
- no loss of trust from speculative checks

### 2. Derived-state pattern inference

Why it matters:

- domains like ledger projection still need `next_state_override`
- there is likely reusable value in recognizing append-only log + projected
  scalar patterns

Success looks like:

- fewer manual `next_state_override` cases for log/projection domains
- analyzer facts that explicitly represent derived-state relationships

### 3. Domain-pattern generalization

Why it matters:

- several strong example domains now exist
- the next step is deciding what should become first-class generator behavior

Success looks like:

- explicit identification of reusable patterns worth hardening
- less config needed for repeated families of domains
- no regression in current practical workflows

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
- `pbt` protocol history:
  - `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/docs/pbt-stateful-api-feedback-2026-03-07.md`
