# spec-to-pbt (Ruby package name: `spec_to_pbt`)

A practical scaffold generator for turning formal-ish specifications into Ruby Property-Based Tests, with a current focus on `pbt`-compatible stateful PBT workflows.

Project status / handoff docs:

- v0 positioning / support matrix:
  - [docs/v0-release-candidate-2026-03-15.md](docs/v0-release-candidate-2026-03-15.md)
- manual trial template:
  - [docs/manual-trial-template-2026-03-15.md](docs/manual-trial-template-2026-03-15.md)

- current state and restart guide:
  - [docs/current-state-and-next-plan-2026-03-09.md](docs/current-state-and-next-plan-2026-03-09.md)
- domain pattern catalog:
  - [docs/domain-pattern-catalog-2026-03-09.md](docs/domain-pattern-catalog-2026-03-09.md)
- stateful generator refactor plan:
  - [docs/stateful-generator-refactor-plan-2026-03-11.md](docs/stateful-generator-refactor-plan-2026-03-11.md)
- product evaluation playbook:
  - [docs/product-evaluation-playbook-2026-03-12.md](docs/product-evaluation-playbook-2026-03-12.md)
- active evaluation TODO:
  - [docs/product-evaluation-todo-2026-03-13.md](docs/product-evaluation-todo-2026-03-13.md)
- active evaluation friction log:
  - [docs/evaluation-friction-log-2026-03-13.md](docs/evaluation-friction-log-2026-03-13.md)
- portfolio evaluation plan:
  - [docs/portfolio-evaluation-plan-2026-03-14.md](docs/portfolio-evaluation-plan-2026-03-14.md)
- portfolio evaluation results:
  - [docs/portfolio-evaluation-results-2026-03-14.md](docs/portfolio-evaluation-results-2026-03-14.md)
- evaluation summary:
  - [docs/evaluation-summary-2026-03-14.md](docs/evaluation-summary-2026-03-14.md)
- evaluation narrative:
  - [docs/evaluation-narrative-2026-03-14.md](docs/evaluation-narrative-2026-03-14.md)
- retrospective / engineering history:
  - [docs/stateful-scaffold-retrospective-2026-03-09.md](docs/stateful-scaffold-retrospective-2026-03-09.md)
- roadmap:
  - [docs/stateful-scaffold-roadmap-2026-03-04.md](docs/stateful-scaffold-roadmap-2026-03-04.md)

## Concept

Auto-generate Property-Based Tests (PBT) from specifications to automate the "spec -> implementation -> test" loop.

- Input:
  - Alloy specification (`.als`)
  - experimental Quint specification (`.qnt`)
- Output: Ruby test code compatible with [pbt gem](https://github.com/ohbarye/pbt) (`.rb`)
- Direction: evolve from `Alloy -> PBT` into a broader `spec -> pbt` experiment space

## Current Phase

The current phase is a **v0 release-candidate hardening pass**.

The product claim is deliberately narrow:

- input: Alloy specs
- output: runnable Ruby PBT scaffolds
- first-class: recurring, structurally safe valid-path updates
- config-assisted / config-owned: observed-state wiring, richer initial state, mixed guards, and invalid-path semantics

Use these docs as the current contract:

- [docs/v0-release-candidate-2026-03-15.md](docs/v0-release-candidate-2026-03-15.md)
- [docs/portfolio-evaluation-results-2026-03-14.md](docs/portfolio-evaluation-results-2026-03-14.md)

The current weak spot remains invalid-path coverage: generated workflows are strongest
on valid-path structural behavior and conservative about richer invalid-path semantics.

## Usage

### Fastest practical workflow

For stateful work, prefer this path:

1. generate with `--stateful --with-config`
2. edit `*_pbt_config.rb`
3. add `*_impl.rb`
4. run the scaffold with `ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1`

```bash
bundle install

# Smallest practical stateful workflow
bin/spec_to_pbt spec/fixtures/alloy/stack.als --stateful --with-config -o generated
vi generated/stack_pbt_config.rb
vi generated/stack_impl.rb
ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec generated/stack_pbt.rb
```

If your bundled `pbt` does not yet provide `Pbt.stateful`, update it first:

```bash
bundle update pbt
```

You can still override with a local checkout when needed:

```bash
PBT_REPO_DIR=/path/to/pbt \
ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec generated/stack_pbt.rb
```

Stateful scaffolds require `pbt >= 0.6.0` with `Pbt.stateful`.
If the generated scaffold raises a runtime preflight error, install or update `pbt`
before rerunning the generated spec.

Stateless generation remains available:

```bash
bin/spec_to_pbt spec/fixtures/alloy/sort.als -o generated
bundle exec rspec generated/sort_pbt.rb
```

Experimental Quint generation is available via auto-detection or `--frontend quint`:

```bash
# Stateful Quint scaffold
bin/spec_to_pbt spec/fixtures/quint/counter.qnt --stateful --quint-cli /path/to/quint -o generated

# Stateless Quint scaffold
bin/spec_to_pbt spec/fixtures/quint/normalize.qnt --frontend quint --quint-cli /path/to/quint -o generated
```

Quint CLI resolution order is:

1. `--quint-cli PATH`
2. `quint` on `PATH`
3. `npx --yes @informalsystems/quint`

Generated tests require a corresponding `*_impl.rb` file. The **module name** becomes the operation name:

```ruby
# generated/sort_impl.rb (for module "sort")
def sort(array)
  array.sort
end

# Helper for invariant pattern
def invariant?(array)
  array.each_cons(2).all? { |a, b| a <= b }
end
```

For `--stateful`, the generated file is intentionally a scaffold rather than a semantics-preserving translation.
It is expected that you will:

- provide a `*_impl.rb` implementation object
- customize model state representation as needed
- refine `next_state` when domain semantics need more than the inferred model update
- refine `verify!` when domain-specific checks go beyond the generated safe assertions
- prefer editing `*_pbt_config.rb` for durable SUT wiring when using `--with-config`

With `--stateful --with-config`, the generator also emits a companion Ruby config file
that is intended to survive regeneration:

- `*_pbt.rb`
  - regenerate freely
- `*_pbt_config.rb`
  - user-owned SUT wiring and API mapping
- `*_impl.rb`
  - user-owned implementation

The generated config now includes field-aware suggestions for:

- likely Ruby API method names
- `arguments_override` for invalid-path coverage or custom argument distributions
- `verify_override` shapes
- `verify_context[:state_reader]`
- `initial_state`
- `next_state_override` for cases where the scaffold needs a richer model transition than the inferred default
- `guard_failure_policy` for inferred guarded commands when you want invalid calls to be treated as `:no_op`, `:raise`, or delegated to a custom invalid-path contract

The config can map spec command names to real Ruby APIs, for example:

```ruby
StackPbtConfig = {
  sut_factory: -> { Stack.new },
  command_mappings: {
    push_adds_element: {
      method: :push,
      verify_override: ->(after_state:, observed_state:) do
        raise "Expected SUT state to match model" unless observed_state == after_state
      end
    },
    pop_removes_element: { method: :pop }
  },
  verify_context: {
    state_reader: ->(sut) { sut.to_a }
  }
}
```

`verify_override` receives the normal verification inputs plus `observed_state:` when
`verify_context[:state_reader]` is configured. For inferred guarded commands it also
receives `guard_failed:` and `guard_failure_policy:` so custom invalid-path behavior
can stay in config instead of requiring direct scaffold edits.
When `verify_context[:state_reader]` is configured and `verify_override` is left unset,
the generated scaffold compares observed state to the model by default.
When only `model_arg_adapter` is configured, the scaffold reuses it for `run!` as the
default `arg_adapter` so model/SUT arguments stay aligned unless you explicitly split them.
For inferred guarded commands:

- `guard_failure_policy: :no_op` asserts unchanged model/observed state
- `guard_failure_policy: :raise` asserts captured exceptions plus unchanged state
- `guard_failure_policy: :custom` delegates the invalid path to `verify_override`
  while keeping the conservative model default of unchanged state unless you also
  provide `next_state_override`

The intended boundary is:

- keep recurring, structurally safe transitions in the generator
- keep invalid-path argument selection in `arguments_override`
- keep unsupported guards in `applicable_override`
- keep domain-specific invalid-path semantics in `verify_override`
- keep richer failure-state model changes in `next_state_override`

For the up-to-date promotion rule and domain matrix, use:

- `docs/current-state-and-next-plan-2026-03-09.md`
- `docs/domain-pattern-catalog-2026-03-09.md`

The scaffold now includes analyzer-driven hints such as:

- inferred state target (for example `Stack#elements` or `Machine#value`)
- inferred transition kind
- related assertions / facts / property predicates
- suggested verification order
- safe executable checks for cases such as non-negative scalar invariants, membership-after-append, and field-to-field scalar replacement when they can be inferred

## Examples

Start with:

- `example/stateful/stack_pbt.rb`
- `example/stateful/bounded_queue_pbt.rb`
- `example/stateful/bank_account_pbt.rb`

Use the example guide for category-based paths:

- [example/stateful/README.md](example/stateful/README.md)

Working examples are provided in `example/`:

```bash
# Run a practical stateful example with config-driven API mapping
# The examples use the bundled pbt gem by default (override with PBT_REPO_DIR if needed)
ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec example/stateful/stack_pbt.rb

# Run a bounded queue example with structured model state and inferred capacity guards
ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec example/stateful/bounded_queue_pbt.rb

# Run a financial-domain example with state-aware amount generation
ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec example/stateful/bank_account_pbt.rb
```

See `example/impl/` for sample implementations.
See `example/stateful/` for config-aware stateful examples using `method:` remapping,
`verify_override`, `verify_context[:state_reader]`, `initial_state`, `next_state_override`,
`model_arg_adapter`, and where useful
`arguments(state)` / `applicable?(state, args)`. The stateful examples use the bundled
`pbt` gem by default and can be redirected with `PBT_REPO_DIR`.
`model_arg_adapter`, `arguments_override`, and where useful
`arguments(state)` / `applicable?(state, args)`. The stateful examples use the bundled
`pbt` gem by default and can be redirected with `PBT_REPO_DIR`.

For current product boundaries and restart context:

- [docs/current-state-and-next-plan-2026-03-09.md](docs/current-state-and-next-plan-2026-03-09.md)
- [docs/domain-pattern-catalog-2026-03-09.md](docs/domain-pattern-catalog-2026-03-09.md)
- [docs/product-evaluation-todo-2026-03-13.md](docs/product-evaluation-todo-2026-03-13.md)
- [docs/portfolio-evaluation-results-2026-03-14.md](docs/portfolio-evaluation-results-2026-03-14.md)
- [docs/evaluation-friction-log-2026-03-13.md](docs/evaluation-friction-log-2026-03-13.md)

Useful stateful fixtures to try:

- `spec/fixtures/alloy/bounded_queue.als`
  - collection state + capacity guard + FIFO-oriented properties
- `spec/fixtures/alloy/bank_account.als`
  - scalar state + fixed/amount-based balance updates, useful for financial-domain exploration
- `spec/fixtures/alloy/wallet_with_limit.als`
  - structured scalar state (`balance` + stable limit field) that now generates a hash model scaffold
- `spec/fixtures/alloy/hold_capture_release.als`
  - multi-field financial state (`available` + `held`) with paired increment/decrement updates
- `spec/fixtures/alloy/transfer_between_accounts.als`
  - paired balance transfer with amount-aware guards and total-preservation style checks
- `spec/fixtures/alloy/refund_reversal.als`
  - settlement capture/refund/reversal flow with multi-field balance preservation
- `spec/fixtures/alloy/ledger_projection.als`
  - append-only ledger entries plus derived balance, now generated as a structured collection + projected scalar scaffold
- `spec/fixtures/alloy/inventory_projection.als`
  - append-only inventory adjustments plus projected stock, used to confirm the ledger-style derived-state pattern is recurring
- `spec/fixtures/alloy/rate_limiter.als`
  - structured scalar state (`remaining` + `capacity`) with reset-to-capacity behavior
- `spec/fixtures/alloy/connection_pool.als`
  - paired counters (`available` + `checked_out`) with capacity-preservation style checks
- `spec/fixtures/alloy/feature_flag_rollout.als`
  - rollout percentage state with enable/disable, constant reset, and first-class bounded rollout generation
- `spec/fixtures/alloy/authorization_expiry_void.als`
  - authorization hold release via void/expiry with amount-aware guards
- `spec/fixtures/alloy/partial_refund_remaining_capturable.als`
  - three-field payment state (`authorized` / `captured` / `refunded`) for partial refund flows
- `spec/fixtures/alloy/job_queue_retry_dead_letter.als`
  - job lifecycle counters (`ready` / `in_flight` / `dead_letter`) with retry and dead-letter transitions
- `spec/fixtures/alloy/payment_status_lifecycle.als`
  - scalar status machine with inferred equality guards and constant status transitions
- `spec/fixtures/alloy/job_status_lifecycle.als`
  - job workflow status machine with inferred equality guards and config-driven invalid-transition handling
- `spec/fixtures/alloy/payment_status_counters.als`
  - mixed payment status + counters domain used to confirm recurring mixed multi-field status transitions
- `spec/fixtures/alloy/job_status_counters.als`
  - mixed job status + retry/dead-letter counters used to confirm the same composite status/counter family
- `spec/fixtures/alloy/payment_status_amounts.als`
  - mixed payment status + amount movement used to confirm the same family across amount-based domains
- `spec/fixtures/alloy/payout_status_amounts.als`
  - mixed payout status + amount movement used to confirm recurring status+amount transitions
- `spec/fixtures/alloy/ledger_status_projection.als`
  - status machine + append-only projection, used to confirm collection projection remains valid with lifecycle guards
- `spec/fixtures/alloy/inventory_status_projection.als`
  - inventory status machine + append-only projection, used to confirm the same family in a second domain
- `spec/fixtures/alloy/payment_status_event_amounts.als`
  - status-gated append-only events plus paired amount movement, used to test where mixed guards stay config-owned
- `spec/fixtures/alloy/job_status_event_counters.als`
  - status-gated append-only events plus paired counter movement, used to confirm the same mixed-guard boundary in a second domain

Practical workflow coverage now includes regeneration-oriented integration specs for:

- `bounded_queue.als` -> generated scaffold + generated config + user-owned impl/config edits
- `bank_account.als` -> generated scaffold + config-driven API remapping + amount-aware commands
- `hold_capture_release.als` -> CLI-regenerated scaffold + config-driven initial state + observed-state verification
- `transfer_between_accounts.als` -> CLI-regenerated scaffold + config-driven initial state + transfer balance verification
- `refund_reversal.als` -> CLI-regenerated scaffold + observed settlement-state verification
- `ledger_projection.als` -> CLI-regenerated scaffold + observed-state verification for derived ledger state
- `inventory_projection.als` -> CLI-regenerated scaffold + observed-state verification for a second append-only projection domain
- `rate_limiter.als` -> CLI-regenerated scaffold + config-driven initial state + observed limiter-state verification
- `connection_pool.als` -> CLI-regenerated scaffold + paired-counter observed-state verification
- `feature_flag_rollout.als` -> CLI-regenerated scaffold + config-driven rollout mapping without custom disable `next_state_override`
- `authorization_expiry_void.als` -> CLI-regenerated scaffold + observed authorization-state verification
- `partial_refund_remaining_capturable.als` -> CLI-regenerated scaffold + three-field payment-state verification
- `job_queue_retry_dead_letter.als` -> CLI-regenerated scaffold + observed queue lifecycle verification
- `payment_status_lifecycle.als` -> CLI-regenerated scaffold + invalid-transition raise handling for a payment status machine
- `job_status_lifecycle.als` -> CLI-regenerated scaffold + method remapping for a job status machine
- `payment_status_counters.als` -> CLI-regenerated scaffold + observed-state verification for mixed payment status/counter transitions
- `job_status_counters.als` -> CLI-regenerated scaffold + method remapping and observed-state verification for mixed job status/counter transitions
- `payment_status_amounts.als` -> CLI-regenerated scaffold + observed-state verification for mixed payment status/amount transitions
- `payout_status_amounts.als` -> CLI-regenerated scaffold + observed-state verification for mixed payout status/amount transitions
- `ledger_status_projection.als` -> CLI-regenerated scaffold + observed-state verification for status-gated append-only ledger projection
- `inventory_status_projection.als` -> CLI-regenerated scaffold + observed-state verification for status-gated append-only inventory projection
- `payment_status_event_amounts.als` -> CLI-regenerated scaffold + observed-state verification for status-gated projection with mixed amount guards via `applicable_override`
- `job_status_event_counters.als` -> CLI-regenerated scaffold + observed-state verification for status-gated projection with mixed counter guards via `applicable_override`
- `hold_capture_release.als` -> user-owned example with multi-field financial state and observed-state verification
- `transfer_between_accounts.als` -> user-owned example with total-preservation style transfer checks
- `refund_reversal.als` -> user-owned example with refund/reversal settlement invariants
- `ledger_projection.als` -> user-owned example with append-only entries and balance projection without custom `next_state_override`
- `inventory_projection.als` -> user-owned example with append-only adjustments and stock projection without custom `next_state_override`
- `rate_limiter.als` -> user-owned example with remaining-capacity reset semantics
- `connection_pool.als` -> user-owned example with paired availability counters
- `feature_flag_rollout.als` -> user-owned example with config-driven rollout range normalization and generated disable reset semantics
- `authorization_expiry_void.als` -> user-owned example with void/expiry authorization release semantics
- `partial_refund_remaining_capturable.als` -> user-owned example with partial refund payment flows
- `job_queue_retry_dead_letter.als` -> user-owned example with retry/dead-letter queue lifecycle checks
- `payment_status_lifecycle.als` -> user-owned example with inferred status guards and invalid-transition raise semantics
- `job_status_lifecycle.als` -> user-owned example with inferred status guards and method-remapped lifecycle transitions
- `payment_status_counters.als` -> user-owned example with status replacement plus counter movement in one command
- `job_status_counters.als` -> user-owned example with lifecycle status plus retry/dead-letter counters
- `payment_status_amounts.als` -> user-owned example with status replacement plus amount movement in one command
- `payout_status_amounts.als` -> user-owned example with payout status plus pending/paid amount movement
- `ledger_status_projection.als` -> user-owned example with status-gated append-only entries and projected balance
- `inventory_status_projection.als` -> user-owned example with status-gated append-only movements and projected stock
- `payment_status_event_amounts.als` -> user-owned example with status-gated event projection and paired amount updates; mixed guards remain config-owned
- `job_status_event_counters.als` -> user-owned example with status-gated event projection and paired counter updates; mixed guards remain config-owned

For current stateful work and roadmap details, see:

- [docs/stateful-scaffold-roadmap-2026-03-04.md](docs/stateful-scaffold-roadmap-2026-03-04.md)
- [docs/pbt-stateful-api-feedback-2026-03-07.md](docs/pbt-stateful-api-feedback-2026-03-07.md) (historical note; now implemented in `pbt` `main`)

## Supported Frontends

### Alloy

Supported syntax:

- `module`, `sig`, `pred`, `assert`, `fact`

### Quint (experimental)

Supported v1 subset:

- top-level `var`
- top-level `action`
- top-level `val`
- stateless modules with exactly one unary top-level `pure def`
- simple action guards and updates that map onto the current scaffold shapes

Explicitly out of scope in v1:

- `temporal` / liveness properties
- multiple pure top-level defs in stateless mode
- unsupported data types beyond the current generator mappings
- richer nondeterministic or branching action semantics that do not map safely to the scaffold

## Supported Patterns (Auto-generated)

These patterns are detected and converted to working Ruby check code. The generator is **generic** - it uses the Alloy module name as the operation name:

| Pattern | Description | Generated Code |
|---------|-------------|----------------|
| idempotent | f(f(x)) == f(x) | `result = op(input); twice = op(result); result == twice` |
| size | Length preservation | `output = op(input); input.length == output.length` |
| roundtrip | Self-inverse | `result = op(input); restored = op(result); restored == input` |
| invariant | Output property | `output = op(input); invariant?(output)` |

Where `op` is replaced with the module name (e.g., `sort`, `reverse`).

## Limitations / Not Yet Supported

### Pattern Detection
- **elements**: Permutation check (`elems = elems`) - detected but not converted to code
- **empty**: Empty state check (`#x = 0`) - detected but not converted to code
- **ordering**: LIFO/FIFO ordering - detected but not converted to code
- **associativity**: `(a + b) + c = a + (b + c)` - detected but not converted to code
- **commutativity**: `a + b = b + a` - detected but not converted to code
- **membership**: Contains/member checks - detected but not converted to code

### Alloy Parsing
- No support for `open` (module imports)
- No support for `fun` (functions)
- No support for `run`/`check` command parameters
- Limited expression parsing (regex-based, not full AST)
- Nested signatures (`sig A { b: B { c: C } }`) not supported

### Code Generation
- Module name is used as the operation name (generic approach)
- `--stateful` generation is a scaffold (command extraction + analyzer-driven hints + TODOs), not a semantics-preserving translator
- `--stateful --with-config` improves SUT connectivity but still relies on explicit user-owned Ruby wiring
- No generation of counterexample shrinking hints
- Stateless generated code may require a manual `*_impl.rb` file with helpers such as `invariant?`
- Stateless generation still assumes generic pattern-compatible inputs in several places
- Stateful generation intentionally falls back to generic TODOs when state shape inference is weak

## Development

```bash
# Run tests
bundle exec rspec

# Type-related checks
bundle exec rbs-inline --output sig/generated lib/

# Steep is currently best-effort and not enforced in CI while the frontend-neutral
# core/stateful refactor settles.
bundle exec steep check
```

### Stateful Development Notes

- The main stateful integration path uses the bundled `pbt` gem by default
- Upgrade with `bundle update pbt` if your lockfile still points at an older release
- Override with `PBT_REPO_DIR=/path/to/pbt` when you need a local checkout
- User-facing stateful workflows assume `pbt >= 0.6.0`
- For repo development only, example specs can still be pointed at a local `pbt` checkout with `PBT_REPO_DIR=/path/to/pbt`
- `pbt >= 0.6.0` now supports:
  - `arguments(state)`
  - `applicable?(state, args)`
  - empty arg-domain handling via `Pbt::Arbitrary::EmptyDomainError`
- The stateful generator now emits those protocol shapes when it can infer them safely
  - for example amount-bounded withdrawals, transfers, and bounded rollout updates
- Stateful scaffold execution in generated specs is gated by:
  - `ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1`
- Stateful generator regression coverage includes:
  - unit specs
  - snapshot specs
  - API contract specs
  - generated scaffold E2E
  - `pbt` call-shape drift detection via contract/E2E coverage

### Type Annotations

This project uses [RBS inline](https://github.com/soutaro/rbs-inline) for type annotations embedded in Ruby source files:

```ruby
# @rbs name: String
# @rbs return: Array[Symbol]
def detect(name, body)
  # ...
end
```

## Architecture

```
Alloy Spec (.als) / Quint Spec (.qnt)
       ↓
    Frontends::Alloy::Parser (regex-based)
    or Frontends::Quint::CLI (`quint parse` + `quint typecheck`)
       ↓
    Frontends::Alloy::Adapter / Frontends::Quint::Adapter
       ↓
    ┌───────────────────────────────┬────────────────────────────────┐
    │ stateless path                │ stateful path                  │
    │                               │                                │
    │ Core::SpecDocument            │ Core::SpecDocument             │
    │ PropertyPattern.detect        │ StatefulPredicateAnalyzer      │
    │ TypeInferrer                  │ StatefulGenerator              │
    │ PatternCodeGenerator          │                                │
    │ unified template/code path    │ scaffold code generation       │
    │                               │                                │
    └───────────────────────────────┴────────────────────────────────┘
       ↓
    Ruby PBT code (.rb)
```

The internal generator path consumes a frontend-neutral core document via
`SpecToPbt::Core`. Alloy and Quint are both adapted into that document model
before reaching the stateless or stateful generators.

See [CLAUDE.md](CLAUDE.md) for detailed architecture documentation.
