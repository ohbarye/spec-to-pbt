# Invalid-Path Evaluation Track

- date: 2026-03-17
- scope: config-only recovery of previously surviving invalid-path mutants

## What changed

- added an integration evaluation that regenerates scaffolds for two survivor domains and reruns them with config-driven invalid-path workflows
- recorded a dedicated invalid-path plan and result note separate from the main valid-path portfolio

## What we learned

- the real gap was evidence, not generator capability
- both survivor mutants were recoverable without editing generated scaffolds once the config intentionally drove invalid calls
- invalid-path recovery needs two different levers:
  - out-of-range argument generation for scalar guard bugs
  - guard-failure execution policy for no-arg command guards
- observed-state verification is already strong enough to act as the oracle once the invalid path is exercised

## Design implications

- invalid-path support should remain config-assisted rather than first-class in the generator for now
- the highest-value improvement is clearer config UX around `arguments_override` and `guard_failure_policy`
- future evaluation should treat invalid-path evidence as its own track instead of mixing it into valid-path structural results

## Next follow-up

1. add or strengthen generated config comments and examples for invalid-path workflows
2. expand the invalid-path track to more domains before considering any promotion
3. keep promotion gated on recurring structural evidence, not on isolated survivor recovery
