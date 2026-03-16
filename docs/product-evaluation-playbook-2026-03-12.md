# Product Evaluation Playbook

## Purpose

Use this document when validating `spec-to-pbt` against real or real-adjacent
domains.

This is the operational companion to:

- `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/docs/current-state-and-next-plan-2026-03-09.md`
- `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/docs/domain-pattern-catalog-2026-03-09.md`

It answers three questions:

1. what domain to try next
2. how to record scaffold friction
3. how to decide whether a pattern should be promoted to first-class generator behavior

## Current Active Pass

The active evaluation pass is tracked in:

- `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/docs/product-evaluation-todo-2026-03-13.md`
- `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/docs/evaluation-friction-log-2026-03-13.md`
- `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/docs/portfolio-evaluation-plan-2026-03-14.md`
- `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/docs/portfolio-evaluation-results-2026-03-14.md`

For the current product phase:

- do not expand Alloy coverage first
- do not add new domains first
- run the selected in-repo domains
- record friction
- classify before promoting anything
- for the current one-month milestone, use the fixed 4-domain portfolio and mutant protocol as the default product evaluation baseline

## Candidate Domain Order

Use this priority order when trying new domains.

### Tier 1: Highest-value financial trials

1. payment authorization with partial capture / partial refund
2. ledger settlement / reconciliation projection
3. payout lifecycle with failure / retry / reversal

These are high value because they combine:

- lifecycle status
- amount movement
- invalid-path semantics
- practical observed-state verification

### Tier 1: Highest-value software-general trials

1. job workflow with retry / dead-letter / activation gates
2. rate limiter with reset / quota depletion / lifecycle toggles
3. connection pool with bounded counters and invalid-path handling

These are high value because they pressure:

- bounded guards
- mixed status + counters
- no-op vs raise invalid paths

### Tier 2: Projection-heavy trials

1. append-only inventory / ledger variants
2. event projection with status gating
3. projection plus bounded invalid paths

These are useful when testing derived-state boundaries, but should be tried
after a Tier 1 domain unless projection is the product focus.

## Trial Workflow

For every new domain, use this sequence.

1. write or adapt an Alloy fixture
2. run:
   - `bin/spec_to_pbt INPUT.als --stateful --with-config -o generated`
3. edit only:
   - `generated/*_pbt_config.rb`
   - `generated/*_impl.rb`
4. avoid editing `generated/*_pbt.rb` unless blocked
5. run:
   - `ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec generated/*_pbt.rb`
   - ensure `pbt >= 0.6.0` is installed so the generated scaffold can call `Pbt.stateful`
6. record all friction using the template below
7. if the same friction appears in a second distinct domain, evaluate promotion
8. classify any undetected mutant as one of:
   - `invalid-path valid-only workflow`
   - `mixed-guard gap`
   - `other`

The key rule is:

- do not immediately generalize from a single domain

## Friction Log Template

Record one row per friction point.

### Minimal fields

- domain:
- fixture:
- command or pattern:
- generated file touched:
  - `*_pbt.rb`
  - `*_pbt_config.rb`
  - `*_impl.rb`
- user action required:
- why generation was insufficient:
- category:
- recurring elsewhere:
- candidate action:

### Category values

- `api_wiring`
- `model_state_shape`
- `unsupported_guard`
- `invalid_path_semantics`
- `derived_state`
- `observed_state_verification`
- `method_suggestion`
- `arg_normalization`
- `generator_bug`
- `documentation_gap`

### Candidate action values

- `leave_in_config`
- `improve_comment_or_docs`
- `improve_config_suggestion`
- `promote_to_generator`
- `fix_bug`

### Example

- domain: `payment authorization with partial capture`
- fixture: `payment_status_amounts.als`
- command or pattern: `capture_amount`
- generated file touched: `*_pbt_config.rb`
- user action required: add `applicable_override`
- why generation was insufficient: guard depends on `status == authorized && amount <= capturable`
- category: `unsupported_guard`
- recurring elsewhere: `partial_refund_remaining_capturable`
- candidate action: `leave_in_config`

## Promotion Decision Procedure

Evaluate promotion only after the same pattern appears in at least two
distinct domains.

Ask these questions in order.

### 1. Is the update shape structurally inferable?

If no:

- do not promote
- keep it config-owned

If yes:

- continue

### 2. Is the guard structurally inferable without dangerous guessing?

If no:

- treat it as `config-assisted`
- keep unsupported preconditions in `applicable_override`

If yes:

- continue

### 3. Does promotion remove real user work?

Promotion is justified only if it removes edits in:

- `initial_state`
- `next_state_override`
- `verify_override`
- `applicable_override`

If promotion only moves logic from one internal branch to another, do not do it.

### 4. Can regenerated workflow coverage hold it green?

A pattern is not ready for first-class support unless it stays green through:

- fixture
- CLI generation
- config/impl-only edits
- regenerated workflow integration

### 5. Can the rule be stated simply?

If the promotion rule cannot be explained in one or two sentences, it is
probably still too domain-specific.

### 6. Did the weakness come from a valid-path miss or from never exercising the path?

If an injected defect survives, separate these cases:

- the generated workflow reached the buggy path and still missed the defect
- the generated workflow never reached the buggy path because it stayed on valid inputs

Only the first case is evidence for missing valid-path generator behavior.
The second case is usually evidence for invalid-path or mixed-guard limits and
should stay config-assisted or config-owned unless a safe recurring strategy appears.

## Boundary Decision Table

### Promote to first-class

Use this when all are true:

- recurring across at least two domains
- structurally inferable update
- structurally inferable guard or safe usefulness without invalid-path guessing
- real config work removed
- regenerated workflow stable

### Keep config-assisted

Use this when:

- update shape is recurring
- but guard, observed-state semantics, or invalid-path semantics still depend on config

Typical examples:

- mixed status + projection + amount/counter
- mixed business-rule preconditions
- reusable update shape with domain-specific invalid path

### Keep config-owned

Use this when:

- business rule dominates
- unsupported guard is essential
- external side effects are central
- observed-state semantics are highly domain-specific

Typical examples:

- gateway/event/audit side effects
- settlement cutoffs
- retry backoff policies
- domain-specific rejection payloads

## Success Criteria For The Current Product Phase

The current product phase is successful if:

1. a new domain can usually be brought to green by editing only:
   - `*_pbt_config.rb`
   - `*_impl.rb`
2. `*_pbt.rb` edits are exceptional rather than normal
3. recurring friction is classified cleanly as:
   - first-class
   - config-assisted
   - config-owned
4. promotion decisions are based on repeated evidence rather than intuition

## Recommended Next Evaluation Pass

If work resumes from here, the next practical pass should be:

1. choose one financial domain from Tier 1
2. choose one software-general domain from Tier 1
3. run both through the trial workflow
4. log all friction
5. only then consider new generator promotion work
