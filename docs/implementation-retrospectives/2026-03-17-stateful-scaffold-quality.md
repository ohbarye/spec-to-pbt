# Stateful Scaffold Quality

- Date: 2026-03-17
- Scope: roughly 2026-03-04 to 2026-03-06

## What changed

This phase established the first serious quality pass on generated stateful scaffolds.

The work concentrated on:

- state-shape inference
- scalar update-shape inference
- command confidence
- analyzer-driven verify hints
- safe executable checks in generated `verify!`
- frontend-neutral core introduction

The output moved away from “everything looks like an array mutation” and toward state-aware scaffolds that could name real targets such as scalar fields and structured state.

## What we learned

The first major learning was that scaffold usefulness depended less on raw command extraction and more on whether the generator could say **what kind of transition it believed it was seeing**.

That changed the quality bar:

- not “did we emit a command class?”
- but “did we infer enough structure to make the generated checks safe and non-misleading?”

The introduction of command confidence was especially important. It acknowledged that not every command-looking predicate deserved the same degree of trust.

The frontend-neutral core was also a strong signal. Once that layer existed, it became clear that long-term progress depended on normalizing semantics before rendering, not on letting the renderer keep accumulating parser-shaped assumptions.

## Design implications

- Semantic facts should be explicit and reviewable before they become renderer branches.
- Confidence is part of product correctness. A weak inference should degrade honestly, not pretend to be certain.
- The generator is most valuable when it refuses to over-claim.

## What not to generalize yet

- Domain-specific postconditions
- Unsupported guards
- Any transition whose update shape is still ambiguous

## Next follow-up

- Push more behavior into analyzer output instead of renderer-local heuristics.
- Keep adding examples that pressure scalar and mixed-structure state.

