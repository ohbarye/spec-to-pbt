# Generator Refactor And Separation

- Date: 2026-03-17
- Scope: roughly 2026-03-11 to 2026-03-12

## What changed

This phase turned the stateful generator from a dense monolith into a more explicit set of components.

The extraction path covered:

- `ConfigRenderer`
- `SupportModuleRenderer`
- `CommandPlan`
- `VerifyRenderer`
- `InitialStateInferencer`
- `SuggestionRenderer`
- guard analysis and projection planning

The public behavior remained stable while the internal structure became more reviewable.

## What we learned

The key structural insight was that maintainability had become the primary technical risk.

Before this refactor, many later feature ideas would have looked harder than they really were, because the generator file mixed:

- semantic interpretation
- rendering decisions
- support helper generation
- suggestion UX

Once those concerns were separated, a clearer rule emerged:

- analyzer and planning layers should decide meaning
- renderers should decide presentation
- support modules should handle runtime protocol glue

This phase also confirmed that refactoring was not a detour from product work. It was a prerequisite for safer pattern promotion.

## Design implications

- Treat semantic planning and output rendering as distinct responsibilities.
- Optimize for reviewability, not just line count reduction.
- Refactor phases should preserve behavior and snapshots whenever possible to keep confidence high.

## What not to generalize yet

- Do not reintroduce semantic branching back into renderer-local helper methods.
- Do not use refactors as cover for changing public behavior unless that change is the actual goal.

## Next follow-up

- Keep future recurring-pattern work flowing through the analyzer and plan objects first.
- Use extraction boundaries as the default review lens for stateful generator changes.

