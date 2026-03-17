# Implementation Retrospective Topics So Far

- Date: 2026-03-17
- Scope: recent implementation learnings worth reusing across future work

## Topic 1: Stateful scaffold hardening was mostly about product boundary, not generator cleverness

### What changed

The stateful path was hardened around:

- scaffold preflight for `Pbt.stateful`
- `arguments_override`
- default observed-state verification via `state_reader`
- clearer config and suggestion comments
- invalid-path evaluation coverage

### What we learned

The main problem was not missing inference power. The main problem was unclear ownership between generator output and user-owned config.

The most effective changes were the ones that made the boundary explicit:

- recurring valid-path structure stays in the generator
- invalid-path argument selection stays in config
- richer observed-state wiring stays in config
- domain-specific invalid semantics stay in config

This confirmed that the project gets more value from tightening the scaffold contract than from prematurely expanding automatic semantics.

### Design implications

- Prefer strengthening config-owned escape hatches over speculative inference.
- Treat scaffold quality and regeneration safety as first-class product behavior.
- Keep invalid-path semantics out of the generator unless a recurring family is proven across domains.

### Next follow-up

- Keep measuring whether friction is really inference-related or mostly config UX.
- Continue promoting only recurring, structurally safe valid-path families.

## Topic 2: Runtime compatibility work was really about making the public path honest

### What changed

The workflow was aligned with released `pbt` support instead of local-repo-only workarounds, and then updated again when `pbt 0.6.0` was released.

### What we learned

This work showed that runtime setup issues are easy to misclassify as generator issues.

The important insight was:

- if the standard user-facing path is not honest, evidence from the repo is weaker than it looks

The transition from local `../pbt` assumptions to released `pbt 0.6.0` support mattered because it made the project claim reproducible outside the author's workspace.

### Design implications

- Separate developer-only fallback paths from the public workflow.
- Make version and runtime requirements explicit in generated output, CLI text, and docs.
- Treat compatibility and install-path clarity as part of product correctness, not just documentation.

### Next follow-up

- Keep compatibility checks versioned and actionable.
- Preserve the rule that repo-local workarounds must not leak into the standard path.

## Topic 3: Quint support is mostly a semantic-hint problem, not a parser problem

### What changed

Quint support grew from a small experimental frontend into comparison-ready coverage for:

- `feature_flag_rollout`
- `job_queue_retry_dead_letter`

This included Quint fixtures, parse/typecheck JSON fixtures, adapter coverage, generator coverage, Quint snapshots, and CLI parity tests.

### What we learned

`job_queue_retry_dead_letter` fit the existing analyzer model cleanly. The hard case was `feature_flag_rollout`.

The real difficulty was not “support Quint syntax”. The real difficulty was preserving the same semantic families across frontends:

- bounded scalar replacement
- sibling-field replacement
- guard meaning
- unchanged-field noise

That led to two strong insights:

1. frontend expansion should be driven by semantic parity, not by syntax coverage alone
2. explicit unchanged assignments are often syntax-level noise and should not dominate inferred model behavior

### Design implications

- Keep the frontend thin when possible, but require rich semantic hints.
- Measure new frontend progress by recurring-family parity, not by raw fixture count.
- Extend adapters only enough to recover existing semantic categories before inventing new generator behavior.

### Next follow-up

- Add future Quint domains only when they pressure a real semantic family.
- Prefer “does this map to an existing recurring family?” over “can we parse this syntax?” as the first question.

## Topic 4: Topic-based retrospectives are more reusable than task-by-task logs

### What changed

A dedicated retrospective workflow was defined and turned into the `implementation-retrospective` skill, with default saving under `docs/implementation-retrospectives/`.

### What we learned

Implementation logs by themselves do not create reusable engineering knowledge. The reusable part comes from grouping work by the decision it informs:

- boundary decisions
- runtime honesty
- semantic parity
- evaluation strategy

This makes the notes more useful for future planning, PR explanation, and architectural trade-off discussions.

### Design implications

- Organize future retrospectives around topics, not only around dates or tasks.
- Prefer notes that answer “what should change next time?” over notes that only describe what happened.
- Keep the saved artifact shorter than the reasoning used to derive it.

### Next follow-up

- Accumulate one note per meaningful topic cluster, not one note per small edit.
- When a topic repeats, update or supersede the previous note instead of scattering near-duplicates.
