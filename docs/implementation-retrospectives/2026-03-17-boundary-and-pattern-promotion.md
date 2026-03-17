# Boundary And Pattern Promotion

- Date: 2026-03-17
- Scope: roughly 2026-03-09 to 2026-03-10

## What changed

This phase expanded domain coverage and, more importantly, clarified which recurring patterns deserved promotion.

Key additions in this period included:

- structured scalar state scaffolds
- constant replacement and bounded replacement
- guard-failure policy support
- derived-state and projection workflows
- lifecycle status transitions
- a domain pattern catalog
- explicit config-owned boundary language

## What we learned

This was the phase where the project stopped being “a generator with many heuristics” and started becoming “a generator with promotion rules.”

The important learning was that feature growth is only safe when it follows a repeatable standard:

- recurring across distinct domains
- structurally inferable
- removes real user work
- stays stable in regenerated workflows

The other major learning was boundary clarity. Invalid paths, mixed guards, and business-rule-heavy semantics kept trying to pull the generator across the line. Instead of responding with more heuristics, the project defined config-assisted and config-owned territory more explicitly.

That was not a retreat. It was a maturity move.

## Design implications

- Promotion rules are more important than clever one-off wins.
- A documented non-goal can be a strength if it prevents misleading output.
- Domain expansion is most useful when it pressures the boundary, not when it merely increases fixture count.

## What not to generalize yet

- Invalid-path semantics that depend on domain meaning
- Mixed guards that are not structurally safe to infer
- Rich failure-state transitions

## Next follow-up

- Keep new first-class behavior tied to cross-domain evidence.
- Keep using config as the durable customization boundary instead of leaking more logic into generated scaffolds.

