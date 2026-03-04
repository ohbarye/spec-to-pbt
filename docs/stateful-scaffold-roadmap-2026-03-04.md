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

### 4. Stateful scaffold quality improves

Status:

- in progress, major progress already made

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

### 5. Reduce Alloy-specific coupling

Status:

- in progress

Completed:

- introduced `SpecToPbt::StatefulPredicateAnalyzer`
- generation is now gradually moving from direct string heuristics toward
  analyzer-driven intermediate facts

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

### 6. Release hardening

Status:

- not the current focus

Completed:

- snapshot tests
- contract tests
- stateful E2E

Remaining:

- documentation polish
- commit cleanup if needed
- release-time API review
- final alignment check against the desired `pbt` API surface

## Current Position

The project is past MVP validation and is now in the
"stateful scaffold quality improvement" phase.

More specifically:

- the scaffold is already runnable
- the generator is being made less misleading
- analyzer-driven inference is replacing generator-local heuristics

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
- snapshot coverage now includes:
  - `stack`
  - `queue`
  - `sort`
  - `workflow_scalar`
  - `cache_size_preserving`
  - `bag_body_removal`

## Highest-Value Next Work

### 1. Improve analyzer body patterns

Why:

- this is the highest-leverage way to improve scaffold quality
- it keeps complexity in the analyzer rather than spreading it through the generator

Examples:

- better transition-kind inference from body shape
- stronger result-position inference
- better recognition of domain-specific update patterns

### 2. Improve scalar/non-collection update guidance

Why:

- scalar state is where the current scaffold is safest but still generic
- clearer update guidance reduces manual editing cost

Examples:

- distinguish "replace value" from "increment/decrement-like update"
- emit field-aware TODOs based on body shape, not just state target labels

### 3. Reduce command extraction and hint noise

Why:

- the generator is already useful, but false-positive related hints are expensive
- cleaner command selection and cleaner related-hint selection both improve trust

Examples:

- tighten command-like predicate detection
- use analyzer facts more aggressively when associating assertions/facts/properties

### 4. Push more generator decisions behind analyzer output

Why:

- this is the structural step that keeps future Alloy de-coupling possible

Examples:

- move more `next_state` / `verify!` branching onto analyzer facts
- reduce direct predicate-name branching where body-level evidence exists

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
