# spec-to-pbt (Ruby package name: `spec_to_pbt`)

A practical scaffold generator for turning formal-ish specifications into Ruby Property-Based Tests, with a current focus on `pbt`-compatible stateful PBT workflows.

- v0 positioning and support matrix: [docs/v0-release-candidate-2026-03-15.md](docs/v0-release-candidate-2026-03-15.md)
- evaluation results: [docs/portfolio-evaluation-results-2026-03-14.md](docs/portfolio-evaluation-results-2026-03-14.md)
- example guide: [example/stateful/README.md](example/stateful/README.md)

## Concept

Auto-generate Property-Based Tests (PBT) from specifications to automate the "spec -> implementation -> test" loop.

- Input:
  - Alloy specification (`.als`)
  - experimental Quint specification (`.qnt`)
- Output: Ruby test code compatible with [pbt gem](https://github.com/ohbarye/pbt) (`.rb`)

## Current Phase

The current phase is a **v0 release-candidate hardening pass**.

The product claim is deliberately narrow:

- input: Alloy specs
- output: runnable Ruby PBT scaffolds
- first-class: recurring, structurally safe valid-path updates
- config-assisted / config-owned: observed-state wiring, richer initial state, mixed guards, and invalid-path semantics

Quint remains experimental. The current Quint goal is narrower than the Alloy path:

- frontend status: experimental
- comparison status: generate-parity coverage for selected domains
- non-goal in this phase: Quint config+impl green workflow parity

## Prerequisites

This project uses [mise](https://mise.jdx.dev/) to manage the Ruby and Bundler toolchain. Prefix all commands with `mise exec --` to ensure the correct versions are selected.

```bash
mise exec -- bundle install
```

Stateful scaffolds require `pbt >= 0.6.0` with `Pbt.stateful`. If the generated scaffold raises a runtime preflight error, update `pbt` before rerunning the generated spec:

```bash
mise exec -- bundle update pbt
```

## Usage

### Stateful workflow (recommended)

1. Generate with `--stateful --with-config`
2. Edit `*_pbt_config.rb` (SUT wiring, API mapping)
3. Add `*_impl.rb` (domain implementation)
4. Run with `ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1`

```bash
mise exec -- bin/spec_to_pbt spec/fixtures/alloy/stack.als --stateful --with-config -o generated
vi generated/stack_pbt_config.rb
vi generated/stack_impl.rb
mise exec -- env ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec generated/stack_pbt.rb
```

You can override the bundled `pbt` with a local checkout when needed:

```bash
PBT_REPO_DIR=/path/to/pbt \
mise exec -- env ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec generated/stack_pbt.rb
```

### Stateless workflow

```bash
mise exec -- bin/spec_to_pbt spec/fixtures/alloy/sort.als -o generated
mise exec -- bundle exec rspec generated/sort_pbt.rb
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

### Quint (experimental)

```bash
# Stateful Quint scaffold
mise exec -- bin/spec_to_pbt spec/fixtures/quint/counter.qnt --stateful --quint-cli /path/to/quint -o generated

# Stateless Quint scaffold
mise exec -- bin/spec_to_pbt spec/fixtures/quint/normalize.qnt --frontend quint --quint-cli /path/to/quint -o generated
```

Quint CLI resolution order: `--quint-cli PATH` > `quint` on `PATH` > `npx --yes @informalsystems/quint`

## Stateful Scaffold Design

For `--stateful`, the generated file is intentionally a scaffold rather than a semantics-preserving translation. It is expected that you will:

- provide a `*_impl.rb` implementation object
- customize model state representation as needed
- refine `next_state` when domain semantics need more than the inferred model update
- refine `verify!` when domain-specific checks go beyond the generated safe assertions
- prefer editing `*_pbt_config.rb` for durable SUT wiring when using `--with-config`

### Generated file roles

With `--stateful --with-config`, the generator emits three files:

| File | Ownership | Regeneration |
|------|-----------|--------------|
| `*_pbt.rb` | generated | regenerate freely |
| `*_pbt_config.rb` | user-owned | survives regeneration |
| `*_impl.rb` | user-owned | survives regeneration |

### Config capabilities

The generated config includes field-aware suggestions for:

- Ruby API method mappings
- `arguments_override` for invalid-path coverage or custom argument distributions
- `verify_override` shapes
- `verify_context[:state_reader]` for observed-state comparison
- `initial_state` for custom initial model state
- `next_state_override` for richer model transitions
- `guard_failure_policy` (`:no_op`, `:raise`, or `:custom`) for inferred guarded commands

Example config:

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

### Design boundary

- **Generator-owned**: recurring, structurally safe transitions
- **Config-owned**: invalid-path argument selection (`arguments_override`), unsupported guards (`applicable_override`), domain-specific invalid-path semantics (`verify_override`), richer failure-state model changes (`next_state_override`)

The scaffold also includes analyzer-driven hints: inferred state target, transition kind, related assertions/facts, suggested verification order, and safe executable checks where structurally inferable.

## Examples

Start with these stateful examples:

```bash
# Stack: smallest practical stateful scaffold
mise exec -- env ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec example/stateful/stack_pbt.rb

# Bounded queue: collection state + capacity guards
mise exec -- env ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec example/stateful/bounded_queue_pbt.rb

# Bank account: financial-domain with amount-aware generation
mise exec -- env ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec example/stateful/bank_account_pbt.rb
```

The `example/stateful/` directory contains 24+ working examples across these categories:

| Category | Examples | Key patterns |
|----------|----------|--------------|
| Core | `stack`, `bounded_queue` | collection mutation, capacity guards |
| Financial | `bank_account`, `hold_capture_release`, `transfer_between_accounts`, `refund_reversal` | scalar/multi-field balance, paired counters |
| Software-general | `rate_limiter`, `connection_pool`, `feature_flag_rollout` | reset semantics, paired availability counters |
| Projection | `ledger_projection`, `inventory_projection` | append-only entries + derived state |
| Lifecycle | `payment_status_lifecycle`, `job_status_lifecycle` | status machine with equality guards |
| Composite | `payment_status_counters`, `ledger_status_projection`, etc. | mixed patterns (status + counters/amounts/projection) |

See [example/stateful/README.md](example/stateful/README.md) for the full category-based guide.

All examples have corresponding regeneration-oriented integration specs that verify the generate-then-customize workflow survives CLI regeneration.

## Supported Frontends

### Alloy

Supported syntax: `module`, `sig`, `pred`, `assert`, `fact`

### Quint (experimental)

Supported v1 subset: top-level `var`, `action`, `val`, and stateless modules with exactly one unary top-level `pure def`.

Out of scope: `temporal` / liveness properties, multiple pure top-level defs, richer nondeterministic or branching action semantics.

## Supported Patterns (stateless, auto-generated)

| Pattern | Description | Generated Code |
|---------|-------------|----------------|
| idempotent | f(f(x)) == f(x) | `result = op(input); twice = op(result); result == twice` |
| size | Length preservation | `output = op(input); input.length == output.length` |
| roundtrip | Self-inverse | `result = op(input); restored = op(result); restored == input` |
| invariant | Output property | `output = op(input); invariant?(output)` |

Where `op` is replaced with the module name (e.g., `sort`, `reverse`).

## Limitations

### Alloy Parsing
- No support for `open` (module imports), `fun` (functions), or `run`/`check` command parameters
- Limited expression parsing (regex-based, not full AST)

### Code Generation
- `--stateful` generation is a scaffold, not a semantics-preserving translator
- Stateful generation intentionally falls back to generic TODOs when state shape inference is weak
- Stateless generated code may require a manual `*_impl.rb` with helpers

### Stateless Pattern Detection
- `elements`, `empty`, `ordering`, `associativity`, `commutativity`, `membership` are detected but not converted to code

## Development

```bash
# Run tests
mise exec -- bundle exec rspec

# Type-related checks
mise exec -- bundle exec rbs-inline --output sig/generated lib/

# Steep is best-effort and not enforced in CI
mise exec -- bundle exec steep check
```

### Stateful Development Notes

- The main stateful integration path uses the bundled `pbt` gem by default
- Override with `PBT_REPO_DIR=/path/to/pbt` when you need a local checkout
- Stateful scaffold execution is gated by `ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1`
- `pbt >= 0.6.0` supports `arguments(state)`, `applicable?(state, args)`, and `Pbt::Arbitrary::EmptyDomainError`

### Type Annotations

This project uses [RBS inline](https://github.com/soutaro/rbs-inline) for type annotations:

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
       |
    Frontends::Alloy::Parser (regex-based)
    or Frontends::Quint::CLI (quint parse + quint typecheck)
       |
    Frontends::Alloy::Adapter / Frontends::Quint::Adapter
       |
    Core::SpecDocument (frontend-neutral)
       |
    +-------------------------------+--------------------------------+
    | stateless path                | stateful path                  |
    |                               |                                |
    | PropertyPattern.detect        | StatefulPredicateAnalyzer      |
    | TypeInferrer                  | GuardInferencer                |
    | PatternCodeGenerator          | StateUpdateInferencer          |
    |                               | StatefulGenerator              |
    |                               |   CommandPlan                  |
    |                               |   ConfigRenderer               |
    |                               |   VerifyRenderer               |
    |                               |   SupportModuleRenderer        |
    |                               |   InitialStateInferencer       |
    |                               |   ProjectionPlan               |
    |                               |   SuggestionRenderer           |
    +-------------------------------+--------------------------------+
       |
    Ruby PBT code (.rb)
```

See [CLAUDE.md](CLAUDE.md) for detailed architecture documentation.

## Internal Docs

Development-oriented documentation (not required for using the tool):

- [Current state and restart guide](docs/current-state-and-next-plan-2026-03-09.md)
- [Domain pattern catalog](docs/domain-pattern-catalog-2026-03-09.md)
- [Evaluation summary](docs/evaluation-summary-2026-03-14.md)
- [Invalid-path evaluation results](docs/invalid-path-evaluation-results-2026-03-17.md)
- [Stateful generator refactor plan](docs/stateful-generator-refactor-plan-2026-03-11.md)
- [Evaluation friction log](docs/evaluation-friction-log-2026-03-13.md)
- [Retrospective / engineering history](docs/stateful-scaffold-retrospective-2026-03-09.md)
- [Roadmap](docs/stateful-scaffold-roadmap-2026-03-04.md)
- [Manual trial template](docs/manual-trial-template-2026-03-15.md)
- [Quint dual-domain comparison](docs/quint-dual-domain-comparison-2026-03-17.md)
