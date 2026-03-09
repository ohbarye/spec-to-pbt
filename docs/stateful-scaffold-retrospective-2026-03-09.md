# Stateful Scaffold Retrospective (2026-03-09)

## Purpose

This document records the practical engineering decisions behind the recent
`spec-to-pbt` work, especially around stateful scaffold generation.

Read `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/docs/current-state-and-next-plan-2026-03-09.md`
first when resuming work. Read this retrospective when you need the decision
history, tradeoffs, and lessons.

It is not a roadmap. The roadmap already exists.
This note is a retrospective and design-history document for:

- what we tried
- what changed
- what failed or was awkward
- what we learned
- why the current architecture looks the way it does

## Starting Point

At the start of this phase, the project had already moved past the original
`alloy-to-pbt` naming and into the renamed `spec-to-pbt` codebase.
The working assumptions were:

- repository name: `spec-to-pbt`
- Ruby module: `SpecToPbt`
- entrypoint: `spec_to_pbt`
- CLI: `bin/spec_to_pbt`
- stateful PBT backend: `pbt`

The initial stateful goal was not a semantics-preserving Alloy translator.
The goal was to generate a runnable, useful, human-finishable stateful `pbt`
scaffold.

That distinction drove almost every later decision.

## Core Decision: Generate Practical Scaffolds, Not Perfect Translations

This was the most important product decision.

We explicitly chose:

- generate code that runs
- avoid pretending to prove semantic equivalence
- prefer safe TODOs over dangerous fake precision
- optimize for “easy for a human to finish”

We explicitly did **not** choose:

- a full Alloy AST frontend
- a semantics-preserving translator
- hidden heuristics that silently make strong domain assumptions

This decision kept the project moving.
Without it, we would likely have spent the time building a parser rather than
producing usable tests.

## Phase 1: Make Stateful Generation Exist And Run

### What was added

- `--stateful` generation path
- `SpecToPbt::StatefulGenerator`
- command-like predicate extraction
- fallback generated command when command extraction is weak
- integration coverage for generated stateful scaffold execution

### Why it mattered

This established that the project could produce stateful output that actually
plugged into `Pbt.stateful` and `Pbt.assert`.

That changed the project from “interesting idea” to “tool with a real feedback
loop”.

### What we learned

The first hard boundary appeared immediately:
stateful PBT is not just “more properties”.
It needs explicit answers for:

- model state
- commands
- applicability
- next-state updates
- postconditions

Any generator that leaves all of those blank is not useful.

## Phase 2: Improve Scaffold Quality With Analyzer-Driven Inference

### The problem

Early stateful generation relied too much on local generator heuristics:

- predicate name patterns
- body text pattern checks
- ad hoc branching in the generator itself

This made the generator hard to trust and hard to extend.

### The change

We introduced `SpecToPbt::StatefulPredicateAnalyzer` as a semantic bridge.
It now extracts intermediate facts such as:

- state params and state type
- argument params
- inferred target field
- multiplicity
- size delta
- transition shape
- guard kind
- rhs source kind
- related assertions/facts/property hints
- derived verify hints

### Why this was the right call

This concentrated interpretation logic in one place and moved the generator
closer to a rendering layer.

That mattered for two reasons:

1. output quality improved
2. future de-Alloy work became structurally possible

### What we learned

The highest-leverage improvements came from improving the analyzer, not by
stacking more rendering heuristics into the generator.

That pattern kept repeating.

## Phase 3: Frontend-Neutral Core Instead Of Alloy-Shaped Internals

### The problem

Even after stateful generation improved, the internals were still Alloy-shaped.
Generators were effectively depending on parser structs that happened to be
simple enough.

That would have made future frontend expansion expensive.

### The change

We introduced:

- a frontend-neutral core model
- an Alloy frontend parser/adapter layer
- generator/analyzer consumption of core entities instead of raw Alloy structs

The visible CLI still accepts Alloy.
The internal architecture no longer assumes that generators must know about
Alloy parser objects.

### Why this was a major decision

This was the point where the project stopped being “an Alloy translator with a
few abstractions” and started becoming “a spec-driven PBT generator with an
Alloy frontend”.

That is a different long-term direction.

### What we learned

Frontend generalization should happen **inside** the architecture first,
not at the CLI first.

Adding more parsers before removing Alloy-shaped internals would have created
structural debt instead of reducing it.

## Phase 4: Practical SUT Connectivity Via Config

### The problem

A runnable scaffold is still not very practical if it assumes:

- exact spec-name to method-name matches
- direct inline edits to generated command classes
- one-off manual rewrites after every regeneration

That is not regeneration-safe.

### The change

We added `--with-config` and a generated companion Ruby config file.
The config became the stable customization surface for:

- `sut_factory`
- `initial_state`
- method mapping
- `arg_adapter`
- `model_arg_adapter`
- `result_adapter`
- `applicable_override`
- `next_state_override`
- `verify_override`
- `state_reader`

### Why this mattered

This was the point where the project became meaningfully more usable in a real
codebase.

The key workflow became:

1. generate scaffold
2. keep `*_pbt.rb` mostly generated
3. put durable wiring in `*_pbt_config.rb`
4. keep implementation in `*_impl.rb`
5. regenerate safely

### What we learned

Generated code is only practical when customization boundaries are explicit.

“Edit the scaffold however you want” is not a practical workflow.
It is just a deferred maintenance problem.

## Phase 5: `pbt` Protocol Feedback Was Necessary

### The problem

Generated stateful commands quickly hit a backend limitation:

- `arguments`
- `applicable?(state)`

was not enough for cases like:

- `withdraw(amount)`
- bounded operations
- any command where applicability depends on both state and selected args

### The feedback and outcome

We documented the issue, reviewed `pbt`, and pushed for additive support for:

- `arguments(state)`
- `applicable?(state, args)`

This was implemented upstream in `pbt` `main`.

### Why this mattered

Without that change, `spec-to-pbt` could still produce good scaffolds, but many
practical domains would require awkward config workarounds.

With that change, the generator could emit much more natural command shapes for:

- amount-bounded financial operations
- bounded queues
- any domain with state-dependent argument ranges

### What we learned

At some point, the bottleneck stopped being `spec-to-pbt` and started being the
backend protocol. Pushing the right additive fix upstream was higher quality
than building more local workarounds.

## Phase 6: Pattern Pressure From Real Domains Changed The Roadmap

### The problem

Once the scaffold became practical, the main question stopped being
"can it run?" and became:

- which patterns are truly recurring?
- which should become first-class?
- which should remain config-owned?

At that point, abstract discussion was no longer enough.
We needed pressure from real domains.

### The change

We added a broad set of practical domains, including:

- financial:
  - bank account
  - hold / capture / release
  - transfer between accounts
  - refund / reversal
  - authorization expiry / void
  - partial refund / remaining capturable
  - payment status lifecycle
- software-general:
  - rate limiter
  - connection pool
  - feature flag rollout
  - job queue retry / dead letter
  - job status lifecycle
- derived-state domains:
  - ledger projection
  - inventory projection

### What changed architecturally

Two repeated patterns crossed the threshold from "interesting example" to
"recurring structural family":

1. append-only collection + projected scalar
2. lifecycle status transitions expressed as scalar equality guards plus
   constant replacement

Those were promoted because they appeared in more than one domain and could be
handled conservatively.

Later, a third recurring family started to become visible:

3. mixed status + counter transitions

That family is not fully promoted in the same way yet, but it is now concrete
enough to influence the roadmap because it appeared in both payment and job
domains.

### What we learned

The right bar for promotion is not "we can probably infer it".
The right bar is:

- recurring in more than one domain
- structurally inferable
- conservative default behavior is possible

That decision rule is now one of the most important project heuristics.

## Phase 7: Regression Strategy Became A Product Concern

### The problem

As the number of practical examples grew, enumerating them manually in tests
became a maintenance risk.
The product claim had shifted from "supports one good example" to
"supports a broad practical workflow set".

### The change

We strengthened regression coverage in two ways:

- regenerated workflow specs kept growing with new domains
- example workflows moved to auto-discovered coverage so new `*_pbt.rb` examples
  are harder to forget

### Why this matters

At this stage, regression coverage is not just test hygiene.
It is how the project preserves trust while heuristics are still evolving.

### What we learned

When a generator becomes practical, workflow coverage matters as much as unit
coverage.
The real contract is no longer just "generated string looks right".
It is:

- generated scaffold
- config
- implementation
- `pbt`
- real execution

all continuing to work together.

## Phase 8: Composite Domain Pressure

### The problem

By this point the generator handled:

- pure status machines
- pure paired counters
- append-only projections

But many practical systems combine those patterns in the same state.
Examples:

- payment status plus authorized/captured counters
- job status plus retry/dead-letter counters

### The change

We added composite domains and used them to force a narrower, safer
generalization:

- first-class:
  - mixed constant replacement
  - mixed increment/decrement/preserve updates in one command
- still config-owned:
  - richer mixed guards
  - business-rule-heavy invalid transitions

### What we learned

This is an important boundary lesson:

- mixed *updates* are often structural
- mixed *preconditions* are much more likely to be domain-owned

That distinction is useful and should keep guiding future work.

## Current Summary

The project is now well past MVP and well past early scaffold-quality work.

The current shape is:

- frontend-neutral internally
- practical and regeneration-safe externally
- backed by broad domain coverage
- intentionally conservative about where automation stops

The remaining work is mostly about keeping that boundary sharp, not about making
the generator maximally aggressive.
stateful protocol contract in `pbt`.

It was correct to fix the backend abstraction rather than keep adding hacks on
the generator side.

## Phase 6: Safe Automation In `verify!`

### The problem

Pure comments in `verify!` are useful but limited.
If everything remains TODO text, the generated scaffold remains too far from a
real test.

### The change

We gradually turned safe cases into executable checks, including:

- non-empty guard checks
- non-negative scalar checks
- preserve-value checks
- preserve-size checks
- append ordering checks where safe
- append/pop roundtrip checks where safe
- membership-after-append checks where safe
- field-to-field replace-value checks where safe
- paired scalar total-preservation checks where safe

### Why the word “safe” matters

We intentionally did **not** auto-generate checks when the semantics were too
speculative.

That was a recurring rule:

- if clearly inferable, generate executable assertions
- if not clearly inferable, generate field-aware guidance instead

### What we learned

The highest-value automation is not “maximum automation”.
It is “automation that does not erode trust”.

Misleading generated assertions are worse than TODOs.

## Phase 7: Richer Model State

### The problem

Simple scalar state or plain collections were not enough for many practical
systems.

Examples:

- bounded queue: collection + capacity
- wallet: balance + limit
- reservations: available + held
- transfer: source + target balances
- queue lifecycle: ready + in_flight + dead_letter

### The change

We extended generation to support structured model state when it was safe to do
so.
This included:

- collection + stable companion scalar fields
- scalar + stable limit/capacity/threshold fields
- paired and multi-field scalar updates
- `initial_state` config override when generator defaults are still too weak
- `next_state_override` for cases like ledger projection where derived state is
  real but not yet inferred automatically

### What we learned

Model richness is the difference between “nice scaffold” and “practical test”.

A weak model infects:

- applicability
- next-state updates
- verification
- usability of generated commands

Improving initial model shape often had more impact than adding another hint in
`verify!`.

## Domain Experiments And What They Taught Us

### Financial domains

We added and iterated on:

- bank account
- hold / capture / release
- transfer between accounts
- refund / reversal
- authorization expiry / void
- partial refund / remaining capturable
- ledger projection

#### What these taught us

- amount-aware commands are essential
- paired scalar fields are common and worth first-class treatment
- total-preservation checks are high-value when safe
- guard-failure semantics matter a lot in finance
- `verify_override` + `state_reader` are the right practical escape hatches
- derived state like ledger balance still benefits from config-level
  `next_state_override`

### Software-general domains

We added and iterated on:

- bounded queue
- rate limiter
- connection pool
- feature flag rollout
- job queue retry / dead letter

#### What these taught us

- structured scalar models generalize beyond finance
- guard-field inference must be precise or applicability breaks quickly
- method-name collisions between commands and state readers are a real practical
  issue
- replace-to-constant and bounded arg replacement are still weaker than paired
  increment/decrement inference

## Notable Challenges

### 1. Guard field selection was easy to get subtly wrong

This showed up in cases like:

- `Release`
- `Checkin`
- `Dispatch` vs `Ack`

The lesson was that “there is a guard” is not enough.
We need the correct guarded field.

### 2. Generated and observed state naming can collide

The `job_queue_retry_dead_letter` example exposed a practical issue where
state-reader naming and command naming overlapped.

That was not a generator problem in the narrow sense, but it was a real
workflow problem.

### 3. Derived state is still a boundary

`ledger_projection` is the clearest example.
The generator can infer enough to scaffold the shape, but derived model updates
still often require a deliberate `next_state_override`.

That is acceptable for now, but it marks a real inference boundary.

### 4. Failure/no-op semantics are important but expensive

We added guidance for guard failures, but we did not aggressively automate
rejection/no-op behavior.

That was an intentional tradeoff.
The protocol and config system can support it, but inference there becomes
more domain-sensitive and easier to mislead.

## Why The Current Architecture Is Defensible

The current stack looks like this for good reasons:

- Alloy frontend remains because it is a productive input format for now
- core document exists because generators should not be Alloy-shaped forever
- analyzer exists because semantic inference should not be spread across the
  generator
- config exists because practical SUT wiring is domain-specific and
  regeneration-safe customization matters
- `verify_override` and `next_state_override` exist because there are real
  boundaries where human knowledge still wins

This is a pragmatic architecture.
It does not pretend to solve the full formal-methods-to-tests problem, but it
solves a large and useful subset.

## Current Position

At this point, the project has:

- runnable stateful scaffold generation
- frontend-neutral internal structure
- upstream `pbt` protocol support for state-aware arguments/applicability
- config-driven SUT wiring
- practical example coverage across financial and software domains
- regenerated workflow integration coverage
- broad snapshot and integration coverage

The generator is now much closer to:

- “practical scaffold generator”

than:

- “research-only demo”

## Main Lessons

If this work had to be summarized into a short list of lessons, it would be:

1. improving the analyzer is usually higher leverage than improving renderer heuristics
2. practical workflow boundaries matter as much as inference quality
3. backend protocol shape matters; some generator problems are really runner-contract problems
4. richer model state is often more valuable than fancier comments
5. safe automation beats ambitious but misleading automation
6. real domain examples expose better engineering truths than abstract discussion

## Open Questions After This Phase

These are the highest-value unresolved questions left by the work so far.

### 1. How far should failure/no-op semantics be automated?

The project now gives guidance, but not strong automatic behavior, for many
invalid-call cases.

That is probably the right default, but the next step is still a real design
choice.

### 2. Should derived-state patterns become a first-class inference target?

`ledger_projection` suggests there is value in recognizing:

- append-only event log
- derived scalar projection

as a reusable domain pattern rather than always relying on `next_state_override`.

### 3. Which remaining domains best expose generator limits?

The best next work is likely chosen by domain pressure, not by abstract feature
checklists.

## Relationship To Other Docs

Use the documents together like this:

- roadmap:
  - `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/docs/stateful-scaffold-roadmap-2026-03-04.md`
- `pbt` integration history:
  - `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/docs/pbt-stateful-api-feedback-2026-03-07.md`
- this retrospective:
  - `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/docs/stateful-scaffold-retrospective-2026-03-09.md`

That split keeps:

- future plan
- upstream protocol history
- local engineering history

separate and readable.
