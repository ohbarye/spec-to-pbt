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

The scaffold now includes analyzer-driven hints such as:

- inferred state target (for example `Stack#elements` or `Machine#value`)
- inferred transition kind
- related assertions / facts / property predicates
- suggested verification order

## Examples

Working examples are provided in `example/`:

```bash
# Run example tests
bundle exec rspec example/generated/sort_pbt.rb
bundle exec rspec example/generated/stack_pbt.rb

# Run a practical stateful example with config-driven API mapping
# The example prefers a local ../pbt checkout (override with PBT_REPO_DIR if needed)
ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec example/stateful/stack_pbt.rb

# Run a bounded queue example with capacity-aware applicable_override
# This example shows the current gap: fullness/capacity guards are wired via config
ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec example/stateful/bounded_queue_pbt.rb

# Run a financial-domain example with API remapping and amount normalization
# The example maps DepositAmount -> credit(amount) via model_arg_adapter
ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec example/stateful/bank_account_pbt.rb
```

See `example/impl/` for sample implementations.
See `example/stateful/` for a config-aware stateful example using `method:` remapping,
`verify_override`, `verify_context[:state_reader]`, and `model_arg_adapter`.

Useful stateful fixtures to try:

- `spec/fixtures/alloy/bounded_queue.als`
  - collection state + capacity guard + FIFO-oriented properties
- `spec/fixtures/alloy/bank_account.als`
  - scalar state + fixed/amount-based balance updates, useful for financial-domain exploration

For current stateful work and roadmap details, see:

- [docs/stateful-scaffold-roadmap-2026-03-04.md](docs/stateful-scaffold-roadmap-2026-03-04.md)
- [docs/pbt-stateful-api-feedback-2026-03-07.md](docs/pbt-stateful-api-feedback-2026-03-07.md)

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
