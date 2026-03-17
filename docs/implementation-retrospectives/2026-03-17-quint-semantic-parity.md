# Quint Semantic Parity

- Date: 2026-03-17
- Scope: roughly 2026-03-16 to 2026-03-17

## What changed

This phase added an experimental Quint frontend path and then pushed it into comparison-ready state for two practical domains:

- `feature_flag_rollout`
- `job_queue_retry_dead_letter`

The work included:

- Quint frontend support
- Quint fixtures and parse/typecheck JSON fixtures
- adapter inference fixes
- stateful scaffold and config generation coverage
- CLI parity tests
- Quint-specific snapshots

## What we learned

The strongest learning from this phase was that frontend expansion is mainly about semantic parity, not syntax throughput.

`job_queue_retry_dead_letter` mapped cleanly to the existing analyzer model. `feature_flag_rollout` exposed the harder part:

- bounded scalar replacement
- sibling-field replacement
- explicit unchanged-field assignments

That revealed a more general rule:

- the frontend only becomes useful when it can recover the same recurring semantic families as the existing frontend

This phase also made explicit that some syntax should be treated as semantic noise. In Quint, explicit unchanged assignments are natural to write, but they should not dominate primary update inference.

## Design implications

- New frontends should be measured by recurring-family parity.
- Adapter work should first try to recover existing semantic categories before inventing new ones.
- Thin frontends are viable if semantic hints are rich enough.

## What not to generalize yet

- Quint green-workflow parity
- broader Quint domain claims beyond the covered comparison set
- new generator behavior invented only to satisfy one frontend's syntax

## Next follow-up

- Add Quint domains when they pressure an important semantic family.
- Keep Alloy/Quint comparison focused on behavioral parity, not literal translation.

