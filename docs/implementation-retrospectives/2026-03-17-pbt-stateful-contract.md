# Pbt Stateful Contract

- Date: 2026-03-17
- Scope: roughly 2026-03-07 to 2026-03-08

## What changed

This phase connected scaffold quality work to the `pbt` backend protocol.

The important change was recognizing that generated commands needed:

- `arguments(state)`
- `applicable?(state, args)`

to model practical domains well. That requirement was captured in the `pbt` API feedback and then reflected back into scaffold generation.

## What we learned

This was a decisive moment for the project because it showed that some generator weaknesses were not really generator weaknesses.

Before this point, there was a temptation to treat awkward domains like bounded queues or withdrawals as “config problems” or “harder inference problems.” The deeper learning was:

- if the backend protocol cannot express the right command shape, no amount of nicer rendering will make the scaffold truly practical

That forced a healthier split:

- fix backend protocol limits in `pbt`
- keep `spec-to-pbt` focused on generating the best scaffold for that protocol

This was one of the strongest examples of the project choosing escalation over workaround.

## Design implications

- Do not bury backend contract problems inside generator hacks.
- When the missing abstraction belongs to the runner, fix it in the runner.
- Generated stateful APIs should be evaluated against realistic domain command shapes, not only toy examples.

## What not to generalize yet

- Domain semantics that still need config even with the improved command protocol
- Any attempt to “fake” arg-aware applicability through documentation alone

## Next follow-up

- Keep the generated scaffold aligned with the actual `pbt` protocol surface.
- Treat protocol drift as a product risk, not just an integration annoyance.

