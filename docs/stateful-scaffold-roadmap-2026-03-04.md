# Stateful Scaffold Roadmap

## Goal

The end goal of `spec-to-pbt` is not a precise Alloy-to-Ruby translator.
The goal is to generate practical `pbt` scaffolds from specs, especially for
stateful properties, such that:

- generated code wires into `Pbt.stateful`
- misleading scaffolds are avoided where inference is weak
- the generated scaffold is easy for a human to finish
- the implementation can evolve away from Alloy-specific assumptions over time

In short:

- input: a formal-ish spec
- output: a usable stateful PBT scaffold

## Milestones

### 1. `pbt` stateful MVP becomes usable

Status:

- done enough for `spec-to-pbt` work to proceed

Completed:

- `pbt` stateful PBT MVP exists
- compatibility with property-style execution/shrinking was established
- stateful E2E and failure-message improvements were already validated

Remaining:

- optional protocol/diagnostic improvements in `pbt`
- not a current blocker for `spec-to-pbt`

### 2. `spec-to-pbt` can generate stateful scaffolds

Status:

- done

Completed:

- `--stateful` path added
- `SpecToPbt::StatefulGenerator` added
- command-like predicate extraction added
- fallback scaffold added when no command-like predicates are found
- repo/code rename completed
  - repo: `spec-to-pbt`
  - module: `SpecToPbt`
  - entry: `spec_to_pbt`
  - CLI: `bin/spec_to_pbt`

Remaining:

- command extraction still has heuristic limits

### 3. Generated scaffolds are executable

Status:

- done

Completed:

- generated scaffold E2E added
- local `pbt` checkout is used for stateful execution
- API contract test added using a stub `Pbt`
- default local `pbt` reference now points to `../pbt`

Remaining:

- keep contract coverage aligned with `pbt` as needed
- keep default `../pbt` integration aligned with `pbt` main call shape

### 4. Stateful scaffold quality improves

Status:

- in progress, but now well into the final practical-quality phase

Completed:

- primed params such as `s'` / `q'` are preserved and used
- snapshot tests added for generated stateful scaffolds
- `verify!` now includes:
  - related assertion/fact hints
  - related property predicate hints
  - suggested verification order
- non-collection state is no longer treated like an array by default
- scalar state guidance now points at the inferred target, e.g. `Machine#value`
- collection-state guidance now points at inferred targets, e.g. `Stack#elements`
- additional fixtures/snapshots were added for:
  - scalar state
  - size-preserving transition
  - body-driven removal semantics

Remaining:

- improve operation inference from predicate bodies
- improve generated `next_state` guidance for scalar/domain-specific transitions
- reduce command extraction and related-hint noise further
- keep fixture/snapshot coverage growing with new analyzer shapes
- decide which repeated domain patterns should become first-class rather than config-driven
- keep broad practical workflow coverage in place as the main regression net

### 5. Reduce Alloy-specific coupling

Status:

- majorly completed, with continued cleanup possible

Completed:

- introduced `SpecToPbt::StatefulPredicateAnalyzer`
- generation is now gradually moving from direct string heuristics toward
  analyzer-driven intermediate facts
- introduced a frontend-neutral core document layer and an Alloy adapter so
  generators no longer depend directly on raw Alloy parser structs

Current analyzer output includes:

- `state_param_names`
- `state_type`
- `argument_params`
- `state_field`
- `state_field_multiplicity`
- `size_delta`
- `requires_non_empty_state`
- `transition_kind`
- `result_position`

Remaining:

- continue moving generator decisions onto analyzer output
- keep Alloy-specific text handling concentrated in the analyzer/front-end layer
- keep promotion of new first-class patterns tied to recurring cross-domain evidence

### 6. Release hardening

Status:

- partly completed, but not the main focus

Completed:

- snapshot tests
- contract tests
- stateful E2E
- regenerated workflow integration specs
- broad practical example coverage across financial and software domains

Remaining:

- documentation polish
- commit cleanup if needed
- release-time API review
- final alignment check against the desired `pbt` API surface
- decide whether the current practical-quality boundary is sufficient for a first real release

## Current Position

The project is past MVP validation and early scaffold-quality work.
It is now in the final practical-quality and domain-generalization phase.

More specifically:

- the scaffold is already runnable
- the generator is substantially less misleading than the initial version
- analyzer-driven inference now covers much more of the generator's branching
- config-driven practical workflows are established
- regenerated workflow coverage is established
- frontend-neutral core and Alloy adapter are established
- recurring pattern coverage now includes:
  - append-only projection across ledger and inventory
  - lifecycle status transitions across payment and job domains

This is the right path for the longer-term goal because it improves output
quality without pushing more Alloy-specific logic directly into the generator.

## Work Completed Toward The Current Phase

### Parsing / inference

- preserved primed state params such as `s'`
- excluded primed/unprimed state pairs from generated command arguments
- introduced `StatefulPredicateAnalyzer`
- added state-field and multiplicity inference
- added transition inference:
  - append
  - pop
  - dequeue
  - size-preserving
- added result-position inference:
  - first
  - last
- improved body-driven transition inference for names like `TakeFront` / `DropLast`

### Scaffold generation

- improved `verify!` guidance with assertion/fact/property hints
- added suggested verification order
- added field-aware comments in `next_state` and `verify!`
- stopped generating array-specific model logic for scalar/non-collection state
- improved initial-state defaults based on inferred state shape

### Test coverage

- full rspec coverage remains green against local `../pbt`
- snapshot coverage and practical workflows now include core structures,
  financial domains, and software-general domains

## Highest-Value Next Work

### 1. Keep the first-class boundary conservative

Why:

- the project now has enough capability that the main risk is over-generalizing
  into domain-owned semantics
- unsupported guards and business-rule-heavy invalid paths should remain
  config-owned unless recurring structural evidence appears

### 2. Promote only recurring structural patterns

Why:

- append-only projection is now confirmed in more than one domain
- lifecycle status transitions are now confirmed in more than one domain
- future generalization should follow the same standard

Examples:

- status + amount/counter hybrid state machines
- richer projection families beyond simple append-only logs
- broader multi-field bounded systems only if they recur across domains

### 3. Keep workflow regression coverage ahead of heuristics

Why:

- broad practical examples now exist
- the product contract is increasingly about end-to-end generated workflows, not
  just unit-level string generation

Examples:

- auto-discovered example workflow coverage
- regenerated workflow coverage for new recurring patterns
- adding a new practical domain only when it strengthens the pattern catalog

## Practical Summary

The project is in a good state:

- stateful generation works
- generated code is executable
- test coverage is strong
- quality work is now compounding through the analyzer layer

The correct near-term strategy is:

1. keep improving `StatefulPredicateAnalyzer`
2. keep moving generator choices onto analyzer output
3. avoid adding raw Alloy heuristics directly into generator code unless necessary
