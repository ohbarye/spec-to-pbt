# v0 Release Candidate

## Positioning

`spec-to-pbt` is a practical scaffold generator, not a semantics-preserving compiler.

- input: Alloy specifications
- output: Ruby property-based test scaffolds for `pbt`
- default workflow: generate scaffold, finish config + impl, run `Pbt.stateful`

## Supported Boundary

### First-class

- collection append / remove workflows
- scalar increment / decrement / replace
- constant replacement / reset-to-boundary
- lifecycle status transitions with structurally safe guards
- multi-field scalar conservation / paired updates
- mixed status + counter / amount transitions when the structural update is inferable

### Config-assisted

- `initial_state`
- `verify_context.state_reader`
- direct observed-state equality without custom `verify_override`
- `model_arg_adapter` / `arg_adapter`
- `arguments_override` for invalid-path coverage and custom distributions
- `guard_failure_policy` for inferred guard-failure handling

### Config-owned

- unsupported or mixed guards
- business-rule-heavy invalid-path semantics
- richer failure-state model transitions
- domain-specific postconditions beyond safe structural checks

## Non-goals

- semantics-preserving Alloy-to-Ruby translation
- arbitrary Alloy coverage expansion as the primary goal
- new frontends in this release-candidate phase
- automatic inference of business-rule-heavy invalid paths

## Release Gate

v0 is ready only when all of the following hold:

1. user-facing standard workflow runs with `pbt >= 0.6.0`
2. generated `*_pbt.rb` stays unedited across the fixed 4-domain portfolio and blind 4-domain expansion
3. the recurring invalid-path guard families are recoverable via config-only workflows
4. `state_reader`-only observed-state verification works for representative domains
5. limitations and non-goals are explicit in the docs and user-facing CLI guidance

## Current Gate Read

Current supporting evidence:

- valid-path product baseline:
  - `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/docs/portfolio-evaluation-results-2026-03-14.md`
- invalid-path config-assisted baseline:
  - `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/docs/invalid-path-evaluation-results-2026-03-17.md`

What the current evidence now shows:

1. the fixed 4-domain valid-path portfolio still reaches green via config/impl-only edits
2. invalid-path recovery is now demonstrated across both recurring families:
   - out-of-range scalar arguments
   - no-arg guard failures
3. generated config guidance now points directly at the invalid-path starting recipes instead of leaving them implicit
