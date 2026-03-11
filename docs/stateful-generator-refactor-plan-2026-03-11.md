# Stateful Generator Refactor Plan

## Purpose

This document is the execution plan for the next code-quality phase.

Use it when the goal is to improve maintainability and structure without
changing the external behavior of `spec-to-pbt`.

Read this after:

- `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/docs/current-state-and-next-plan-2026-03-09.md`
- `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/docs/domain-pattern-catalog-2026-03-09.md`

This document is not a product roadmap. It is a refactor work plan.

## Why This Refactor Exists

The main structural risk is no longer missing pattern support. It is the size
and role-mixing inside the stateful generation path.

Today:

- `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/lib/spec_to_pbt/stateful_generator.rb`
  owns too many responsibilities
- the generator still interprets analyzer output directly in many places
- support/runtime helper code is emitted as raw string arrays inside the same
  class that decides state semantics
- semantic generation and config suggestion UX are mixed together

This makes every new recurring pattern more expensive to add and harder to
review safely.

## Refactor Goal

Keep the current public behavior and current green test baseline while making
future changes cheaper and safer.

Target outcomes:

1. `StatefulGenerator` becomes an orchestrator, not a monolith
2. rendering is separated from semantic planning
3. support-module generation is isolated and reviewable
4. config suggestion logic is separated from semantic scaffold generation
5. guard and projection logic are represented more explicitly

Non-goals:

- changing CLI behavior
- changing the current first-class/config-assisted boundary
- adding new domain coverage as part of the refactor itself
- replacing regex parsing with a new parser

## Current Hotspots

### 1. StatefulGenerator monolith

Main file:

- `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/lib/spec_to_pbt/stateful_generator.rb`

It currently mixes:

- scaffold rendering
- config rendering
- generated runtime/support helper rendering
- initial state inference
- guard handling
- `next_state` rendering
- `verify!` rendering
- method/state-reader/override suggestion UX

### 2. Direct analyzer-to-renderer coupling

The generator repeatedly branches directly on analysis fields instead of working
from a smaller render-oriented plan.

### 3. Stringly-typed generated runtime logic

The support helpers are generated as line arrays in the same file, which makes
behavioral review harder than necessary.

## Recommended Refactor Order

Do these in order. Earlier steps reduce risk for later steps.

### Step 1. Extract config rendering from StatefulGenerator

Create a dedicated renderer, for example:

- `SpecToPbt::StatefulGenerator::ConfigRenderer`

Move into it:

- config file header text
- `sut_factory` rendering
- command mapping entry rendering
- method suggestion comments
- `state_reader` suggestion comments
- `verify_override` / `next_state_override` suggestion comments

Acceptance criteria:

- generated `*_pbt_config.rb` output is unchanged except for intentional
  formatting cleanup
- config snapshot specs stay green
- `StatefulGenerator` only delegates config file generation

Suggested commit boundary:

- one commit containing only the extraction and snapshot/spec updates

### Step 2. Extract support/runtime helper rendering

Create a dedicated renderer, for example:

- `SpecToPbt::StatefulGenerator::SupportModuleRenderer`

Move into it:

- config lookup helpers
- method-resolution helpers
- arg/result adaptation helpers
- override invocation helpers
- guard-failure helper plumbing

Acceptance criteria:

- generated support module content is behaviorally unchanged
- scaffold contract specs remain green
- `StatefulGenerator` no longer contains the large embedded helper renderer

Suggested commit boundary:

- one commit after Step 1, focused only on helper-rendering extraction

### Step 3. Introduce a small command render plan

Add an intermediate object, for example:

- `SpecToPbt::StatefulCommandPlan`

It should capture only what the renderer needs, such as:

- command class name
- method dispatch strategy
- guard strategy
- state-update strategy
- verify strategy
- config suggestion hooks

Important rule:

- this is not a second analyzer
- it is a render-facing normalization layer over `StatefulPredicateAnalysis`

Acceptance criteria:

- `StatefulGenerator` stops re-deriving the same rendering decisions in many
  methods
- command rendering code becomes smaller and more linear
- existing snapshots stay green

Suggested commit boundary:

- one commit introducing the plan object and moving only one or two rendering
  paths onto it first
- if stable, a follow-up commit can finish the migration

### Step 4. Extract VerifyRenderer

Create a dedicated renderer, for example:

- `SpecToPbt::StatefulGenerator::VerifyRenderer`

Move into it:

- safe executable check rendering
- derived verify hint rendering
- guard-failure verification rendering
- projection verification rendering

Why this step matters:

- `verify!` is now one of the densest semantic surfaces in the codebase
- it will keep growing more slowly than before, but it still deserves its own
  boundary

Acceptance criteria:

- verify-related branching leaves the main generator
- verify-specific specs remain readable and green

### Step 5. Extract InitialStateInferencer

Create a dedicated inferencer, for example:

- `SpecToPbt::StatefulGenerator::InitialStateInferencer`

Move into it:

- scalar default initial values
- collection default initial values
- structured hash-state default values
- projection-oriented initial state defaults

Acceptance criteria:

- initial-state decisions are isolated from rendering code
- practical example workflows remain green

### Step 6. Split semantic generation from suggestion UX

Create a dedicated suggestion component, for example:

- `SpecToPbt::StatefulGenerator::SuggestionRenderer`

Move into it:

- likely Ruby API method names
- `state_reader` comment suggestions
- `verify_override` example suggestions
- override guidance comments

Acceptance criteria:

- semantic code generation no longer depends on UX wording helpers
- config snapshots remain green

## Guard Refactor Follow-Up

Do this only after the renderer split is stable.

### Step 7. Replace coarse guard fields with a structured object

Introduce a value object, for example:

- `SpecToPbt::GuardAnalysis`

Recommended fields:

- `kind`
- `field`
- `comparator`
- `constant`
- `argument_name`
- `support_level`

Why:

- the current `guard_kind` + `guard_field` + `guard_constant` shape has been
  enough so far, but it is the next structural limit
- the goal is not to promote mixed guards automatically
- the goal is to represent supported and unsupported guards explicitly

Acceptance criteria:

- supported guard rendering becomes more local and easier to read
- unsupported guard fallback is still explicit
- no boundary change in product behavior

## Projection Refactor Follow-Up

Do this after the guard refactor only if projection logic is still spreading.

### Step 8. Introduce a projection plan

Create a value object, for example:

- `SpecToPbt::ProjectionPlan`

Recommended fields:

- primary collection field
- projected scalar field
- append item expression
- projection verify strategy
- support level

Why:

- append-only projection has now recurred across multiple domains
- projection logic is real enough to deserve a named internal shape

Acceptance criteria:

- ledger / inventory / status-gated projection rendering no longer depends on
  scattered helper heuristics
- projection rules are easier to review and extend

## What Not To Do During This Refactor

Do not combine this refactor with:

- new CLI flags
- new input frontends
- major parser changes
- broad promotion of mixed guard patterns
- speculative invalid-path automation

The point is to lower change cost, not to widen behavior at the same time.

## Test Strategy

Run the same safety net after each step.

Minimum after each extraction:

- `mise exec -- bundle exec rspec spec/spec_to_pbt/stateful_generator_spec.rb`
- `mise exec -- bundle exec rspec spec/spec_to_pbt/stateful_generator_snapshot_spec.rb`
- `mise exec -- bundle exec rspec spec/spec_to_pbt/stateful_generator_config_snapshot_spec.rb`
- `mise exec -- bundle exec rspec spec/integration/stateful_scaffold_contract_spec.rb`

After each stable milestone:

- `mise exec -- bundle exec rspec`

If a step touches practical workflow assumptions, also run:

- `mise exec -- bundle exec rspec spec/integration/stateful_example_workflow_spec.rb`
- `mise exec -- bundle exec rspec spec/integration/stateful_regenerated_workflow_spec.rb`

## Suggested Commit Plan

Recommended split:

1. extract config renderer
2. extract support module renderer
3. introduce command render plan
4. extract verify renderer
5. extract initial state inferencer
6. extract suggestion renderer
7. guard analysis object
8. projection plan object

If any step turns out bigger than expected, split it again rather than stacking
multiple responsibility moves into one commit.

## Definition Of Done

This refactor phase is done when all of the following are true:

1. `StatefulGenerator` is substantially smaller and mainly orchestration
2. generated support/runtime code is rendered outside the main generator class
3. config rendering is isolated from scaffold semantics
4. repeated rendering decisions go through an explicit render plan
5. current public behavior and current test baseline remain intact

## Resume Instructions

If resuming this refactor later:

1. read `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/docs/current-state-and-next-plan-2026-03-09.md`
2. read `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/docs/domain-pattern-catalog-2026-03-09.md`
3. read this refactor plan
4. start at the next uncompleted step in the commit plan above
5. keep the boundary rule unchanged unless a separate decision doc says otherwise
