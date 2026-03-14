# Evaluation Narrative

This document is a concise narrative for explaining the current `spec-to-pbt` result.

## One-Sentence Positioning

`spec-to-pbt` explores how far we can get from a formal specification to a useful property-based test workflow without pretending that every domain-specific semantic detail can be inferred automatically.

## Problem

Formal specifications are often disconnected from executable testing practice.

In particular, stateful PBT has high setup cost:

- choose a model state
- choose commands
- define applicability
- define state transitions
- define postconditions

That setup cost is exactly where many specification-to-testing ideas stop being practical.

## Thesis

Instead of aiming for a semantics-preserving compiler from Alloy to Ruby tests, we aim for a practical scaffold generator:

- generate the runnable stateful PBT skeleton
- infer the structurally safe parts
- leave domain-specific wiring in a regeneration-safe config layer

This is a more realistic target for practical use.

## System Shape

The workflow is:

1. start from Alloy
2. generate a `pbt`-compatible stateful scaffold
3. keep the generated scaffold stable
4. finish the last mile in:
   - `*_pbt_config.rb`
   - `*_impl.rb`

The architectural decision is important:

- first-class support only for recurring, structurally safe patterns
- config-assisted support when the update is reusable but the guard or invalid-path semantics are domain-specific

## Evaluation Setup

We evaluated the current system as a 4-domain portfolio:

- financial:
  - partial refund / remaining capturable
  - ledger projection
- software-general:
  - job status event counters
  - connection pool

For each domain we required:

- no hand editing of generated `*_pbt.rb`
- only config + implementation edits
- successful end-to-end execution
- three deterministic injected defects

## Main Result

The strongest result is practical viability:

- all four domains reached green without editing generated scaffold files

The second result is usefulness:

- the generated tests detected realistic recurring defects, especially:
  - wrong field updates
  - wrong update direction
  - projection bugs
  - lifecycle transition bugs

## What This Means

This does **not** mean:

- we can automatically generate perfect tests for arbitrary specs

It **does** mean:

- formal specifications can already be turned into practical stateful PBT workflows
- the practical boundary is not random
- the recurring structural core is large enough to be useful across multiple domains

## Honest Limitation

The current weak area is invalid-path semantics.

Generated workflows tend to stay on valid paths, so bugs such as:

- over-refund allowed
- invalid checkin allowed

are not always exercised automatically.

This is not a surprising failure.
It is exactly the boundary where:

- mixed guards
- business-rule-heavy rejection semantics
- domain-specific invalid paths

remain config-assisted or config-owned.

## Why This Is Still A Good Result

The boundary is explainable and evidence-based.

That matters because it means we are not just showing a demo that happens to work.
We are showing:

- where automatic generation is already viable
- where it still needs explicit human input
- and how those two regions can coexist in one practical workflow

## Short Closing

The project claim should be:

We can already get from formal specs to useful stateful PBT scaffolds in a practical, repeatable way, as long as we treat specification-to-test generation as structured scaffold generation rather than as a fully automatic semantic compiler.
