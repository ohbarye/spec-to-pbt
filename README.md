# spec-to-pbt (Ruby package name: `spec_to_pbt`)

A PoC / spike workspace for generating Ruby Property-Based Tests from specifications, with a current focus on practical `pbt` stateful PBT scaffolding.

## Concept

Auto-generate Property-Based Tests (PBT) from specifications to automate the "spec -> implementation -> test" loop.

- Input (current): Alloy specification (`.als`)
- Output: Ruby test code compatible with [pbt gem](https://github.com/ohbarye/pbt) (`.rb`)
- Direction: evolve from `Alloy -> PBT` into a broader `spec -> pbt` experiment space

## Usage

```bash
bundle install

# Generate PBT from Alloy spec
bin/spec_to_pbt spec/fixtures/alloy/sort.als -o generated

# Generate a stateful PBT scaffold (experimental)
bin/spec_to_pbt spec/fixtures/alloy/stack.als --stateful -o generated

# Generate a stateful scaffold plus a durable SUT mapping config
bin/spec_to_pbt spec/fixtures/alloy/stack.als --stateful --with-config -o generated

# Run generated tests (requires *_impl.rb file in same directory)
bundle exec rspec generated/sort_pbt.rb

# Run a generated stateful scaffold after customization
ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec generated/stack_pbt.rb
```

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
- `verify_override` shapes
- `verify_context[:state_reader]`
- `initial_state`
- `next_state_override` for cases where the scaffold needs a richer model transition than the inferred default

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
`verify_context[:state_reader]` is configured.
When only `model_arg_adapter` is configured, the scaffold reuses it for `run!` as the
default `arg_adapter` so model/SUT arguments stay aligned unless you explicitly split them.

The scaffold now includes analyzer-driven hints such as:

- inferred state target (for example `Stack#elements` or `Machine#value`)
- inferred transition kind
- related assertions / facts / property predicates
- suggested verification order
- safe executable checks for cases such as non-negative scalar invariants, membership-after-append, and field-to-field scalar replacement when they can be inferred

## Examples

Working examples are provided in `example/`:

```bash
# Run example tests
bundle exec rspec example/generated/sort_pbt.rb
bundle exec rspec example/generated/stack_pbt.rb

# Run a practical stateful example with config-driven API mapping
# The example prefers a local ../pbt checkout (override with PBT_REPO_DIR if needed)
ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec example/stateful/stack_pbt.rb

# Run a bounded queue example with structured model state and inferred capacity guards
ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec example/stateful/bounded_queue_pbt.rb

# Run a financial-domain example with state-aware amount generation
# The example maps DepositAmount/WithdrawAmount -> credit(amount)/debit(amount)
ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec example/stateful/bank_account_pbt.rb

# Run a reservation/hold workflow with multi-field financial state
ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec example/stateful/hold_capture_release_pbt.rb

# Run an intra-account transfer workflow with total-preservation checks
ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec example/stateful/transfer_between_accounts_pbt.rb

# Run a settlement refund/reversal workflow with observed-state verification
ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec example/stateful/refund_reversal_pbt.rb

# Run a ledger projection workflow using config-driven next_state overrides
ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec example/stateful/ledger_projection_pbt.rb

# Run a rate limiter workflow with structured remaining-capacity state
ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec example/stateful/rate_limiter_pbt.rb

# Run a connection pool workflow with paired available/checked_out counters
ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec example/stateful/connection_pool_pbt.rb

# Run a feature flag rollout workflow with config-driven rollout mapping
ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec example/stateful/feature_flag_rollout_pbt.rb

# Run an authorization expiry/void workflow with observed-state verification
ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec example/stateful/authorization_expiry_void_pbt.rb

# Run a partial refund workflow with three-field payment state
ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec example/stateful/partial_refund_remaining_capturable_pbt.rb

# Run a job queue retry/dead-letter workflow with observed-state verification
ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec example/stateful/job_queue_retry_dead_letter_pbt.rb
```

See `example/impl/` for sample implementations.
See `example/stateful/` for config-aware stateful examples using `method:` remapping,
`verify_override`, `verify_context[:state_reader]`, `initial_state`, `next_state_override`,
`model_arg_adapter`, and where useful
`arguments(state)` / `applicable?(state, args)`. The stateful examples load a local
`../pbt` checkout by default and can be redirected with `PBT_REPO_DIR`.

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
  - append-only ledger entries plus derived balance, useful for config-driven `next_state_override`
- `spec/fixtures/alloy/rate_limiter.als`
  - structured scalar state (`remaining` + `capacity`) with reset-to-capacity behavior
- `spec/fixtures/alloy/connection_pool.als`
  - paired counters (`available` + `checked_out`) with capacity-preservation style checks
- `spec/fixtures/alloy/feature_flag_rollout.als`
  - rollout percentage state with enable/disable and arg-aware rollout mapping
- `spec/fixtures/alloy/authorization_expiry_void.als`
  - authorization hold release via void/expiry with amount-aware guards
- `spec/fixtures/alloy/partial_refund_remaining_capturable.als`
  - three-field payment state (`authorized` / `captured` / `refunded`) for partial refund flows
- `spec/fixtures/alloy/job_queue_retry_dead_letter.als`
  - job lifecycle counters (`ready` / `in_flight` / `dead_letter`) with retry and dead-letter transitions

Practical workflow coverage now includes regeneration-oriented integration specs for:

- `bounded_queue.als` -> generated scaffold + generated config + user-owned impl/config edits
- `bank_account.als` -> generated scaffold + config-driven API remapping + amount-aware commands
- `hold_capture_release.als` -> CLI-regenerated scaffold + config-driven initial state + observed-state verification
- `transfer_between_accounts.als` -> CLI-regenerated scaffold + config-driven initial state + transfer balance verification
- `refund_reversal.als` -> CLI-regenerated scaffold + observed settlement-state verification
- `ledger_projection.als` -> CLI-regenerated scaffold + config-driven `next_state_override` for derived ledger state
- `rate_limiter.als` -> CLI-regenerated scaffold + config-driven initial state + observed limiter-state verification
- `connection_pool.als` -> CLI-regenerated scaffold + paired-counter observed-state verification
- `feature_flag_rollout.als` -> CLI-regenerated scaffold + config-driven rollout mapping and disable override
- `authorization_expiry_void.als` -> CLI-regenerated scaffold + observed authorization-state verification
- `partial_refund_remaining_capturable.als` -> CLI-regenerated scaffold + three-field payment-state verification
- `job_queue_retry_dead_letter.als` -> CLI-regenerated scaffold + observed queue lifecycle verification
- `hold_capture_release.als` -> user-owned example with multi-field financial state and observed-state verification
- `transfer_between_accounts.als` -> user-owned example with total-preservation style transfer checks
- `refund_reversal.als` -> user-owned example with refund/reversal settlement invariants
- `ledger_projection.als` -> user-owned example with append-only entries and balance projection
- `rate_limiter.als` -> user-owned example with remaining-capacity reset semantics
- `connection_pool.als` -> user-owned example with paired availability counters
- `feature_flag_rollout.als` -> user-owned example with config-driven rollout range normalization
- `authorization_expiry_void.als` -> user-owned example with void/expiry authorization release semantics
- `partial_refund_remaining_capturable.als` -> user-owned example with partial refund payment flows
- `job_queue_retry_dead_letter.als` -> user-owned example with retry/dead-letter queue lifecycle checks

For current stateful work and roadmap details, see:

- [docs/stateful-scaffold-roadmap-2026-03-04.md](docs/stateful-scaffold-roadmap-2026-03-04.md)
- [docs/pbt-stateful-api-feedback-2026-03-07.md](docs/pbt-stateful-api-feedback-2026-03-07.md) (historical note; now implemented in `pbt` `main`)

## Supported Alloy Syntax

- `module`, `sig`, `pred`, `assert`, `fact`

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

- The main stateful integration path uses the local `pbt` checkout at `../pbt` by default
- `../pbt` is expected to track the user's local `main` branch unless `PBT_REPO_DIR` is overridden
- Override with `PBT_REPO_DIR=/path/to/pbt` if needed
- `pbt` `main` now supports:
  - `arguments(state)`
  - `applicable?(state, args)`
  - empty arg-domain handling via `Pbt::Arbitrary::EmptyDomainError`
- The stateful generator now emits those protocol shapes when it can infer them safely
  - for example amount-bounded withdrawals and similar scalar arg-aware commands
- Stateful scaffold execution in generated specs is gated by:
  - `ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1`
- Stateful generator regression coverage includes:
  - unit specs
  - snapshot specs
  - API contract specs
  - generated scaffold E2E
  - `pbt main` call-shape drift detection via contract/E2E coverage

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
Alloy Spec (.als)
       ↓
    Frontends::Alloy::Parser (regex-based)
       ↓
    Frontends::Alloy::Adapter
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

The CLI still accepts Alloy input today, but the internal generator path now consumes
a frontend-neutral core document via `SpecToPbt::Core` and
`SpecToPbt::Frontends::Alloy::Adapter`.

See [CLAUDE.md](CLAUDE.md) for detailed architecture documentation.
