# Evaluation And V0 Positioning

- Date: 2026-03-17
- Scope: roughly 2026-03-12 to 2026-03-15

## What changed

This phase shifted attention from “can we generate more?” to “what exactly are we claiming, and how do we validate it?”

The work included:

- practical workflow guidance
- evaluation playbook
- friction logging
- fixed portfolio evaluation
- narrative and summary docs
- v0 release-candidate positioning
- config UX tightening
- scaffold hardening around `arguments_override`, `state_reader`, and preflight checks

## What we learned

The central learning was that productization for this repo is mostly about **honesty and repeatability**.

At this stage, the limiting factor was not missing domain breadth. It was:

- unclear claims
- inconsistent workflow expectations
- friction that users would experience in the last mile

The evaluation work showed that “green in this repo” is not enough. The workflow has to be understandable, bounded, and reproducible by someone who did not author the generator.

This also reframed docs. They were no longer just project notes. They became part of the product contract.

## Design implications

- Support matrix, non-goals, and release gates are implementation artifacts, not marketing extras.
- Config UX is part of product quality.
- Evaluation should classify friction before proposing promotion.

## What not to generalize yet

- New frontend claims
- Invalid-path first-class support
- Broader parser coverage justified only by curiosity

## Next follow-up

- Keep using fixed evaluation baselines and friction categories.
- Let external/manual trial evidence drive the next expansion, not intuition alone.

