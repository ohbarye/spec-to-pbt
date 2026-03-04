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
- customize model state representation
- refine `next_state`
- refine `verify!`

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
```

See `example/impl/` for sample implementations.

For current stateful work and roadmap details, see:

- [docs/stateful-scaffold-roadmap-2026-03-04.md](docs/stateful-scaffold-roadmap-2026-03-04.md)

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
- No generation of counterexample shrinking hints
- Stateless generated code may require a manual `*_impl.rb` file with helpers such as `invariant?`
- Stateless generation still assumes generic pattern-compatible inputs in several places
- Stateful generation intentionally falls back to generic TODOs when state shape inference is weak

## Development

```bash
# Run tests
bundle exec rspec

# Type checking (RBS inline + Steep)
bundle exec rbs-inline --output sig/generated lib/
bundle exec steep check
```

### Stateful Development Notes

- The main stateful integration path uses the local `pbt` checkout at `../pbt` by default
- Override with `PBT_REPO_DIR=/path/to/pbt` if needed
- Stateful scaffold execution in generated specs is gated by:
  - `ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1`
- Stateful generator regression coverage includes:
  - unit specs
  - snapshot specs
  - API contract specs
  - generated scaffold E2E

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
    Parser (regex-based)
       ↓
    ┌───────────────────────────────┬────────────────────────────────┐
    │ stateless path                │ stateful path                  │
    │                               │                                │
    │ PropertyPattern.detect        │ StatefulPredicateAnalyzer      │
    │ TypeInferrer                  │ StatefulGenerator              │
    │ PatternCodeGenerator          │                                │
    │ unified template/code path    │ scaffold code generation       │
    │                               │                                │
    └───────────────────────────────┴────────────────────────────────┘
       ↓
    Ruby PBT code (.rb)
```

See [CLAUDE.md](CLAUDE.md) for detailed architecture documentation.
