# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

spec_to_pbt is a practical scaffold generator that turns formal-ish specifications
into Ruby Property-Based Tests. The current product focus is Alloy-first,
`pbt`-compatible stateful scaffold generation, with Quint support remaining
experimental.

The strongest current workflow is not "fully automatic test generation". It is:

- generate a runnable scaffold
- keep durable customization in `*_pbt_config.rb`
- keep domain behavior in `*_impl.rb`
- run the result through `Pbt.stateful`

## Commands

Use `mise exec -- ...` in this repository so the intended Ruby/Bundler toolchain is selected.

```bash
# Install dependencies
mise exec -- bundle install

# Run all tests
mise exec -- bundle exec rspec

# Run a single test file
mise exec -- bundle exec rspec spec/spec_to_pbt/parser_spec.rb

# Run a specific test (by line number)
mise exec -- bundle exec rspec spec/spec_to_pbt/parser_spec.rb:14

# Generate PBT from Alloy spec
mise exec -- bin/spec_to_pbt spec/fixtures/alloy/sort.als
mise exec -- bin/spec_to_pbt spec/fixtures/alloy/stack.als -o output_dir

# Run generated tests (requires *_impl.rb file)
mise exec -- bundle exec rspec generated/sort_pbt.rb

# Run stateful example tests
mise exec -- env ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec example/stateful/stack_pbt.rb

# Type checking with Steep
mise exec -- bundle exec rbs-inline --output sig/generated lib/  # Generate RBS from inline annotations
mise exec -- bundle exec steep check                               # Run type check
```

## Architecture

```
Alloy Spec (.als) / Quint Spec (.qnt)
       ↓
    Frontends::Alloy::Parser
    or Frontends::Quint::CLI
       ↓
    Frontends::*::Adapter
       ↓
    Core::SpecDocument
       ↓
    ┌───────────────────────────────┬────────────────────────────────┐
    │ stateless path                │ stateful path                  │
    │ PropertyPattern.detect        │ StatefulPredicateAnalyzer      │
    │ TypeInferrer                  │ StatefulGenerator              │
    │ PatternCodeGenerator          │ config + scaffold rendering    │
    └───────────────────────────────┴────────────────────────────────┘
       ↓
    Ruby PBT code (.rb)
```

### Core Components

1. **Frontends / Parser** (`lib/spec_to_pbt/frontends/`, `lib/spec_to_pbt/parser.rb`): Loads Alloy and experimental Quint inputs into a frontend-neutral document model.

2. **PropertyPattern** (`lib/spec_to_pbt/property_pattern.rb`): Detects common stateless property patterns from predicate names and bodies.

3. **TypeInferrer** (`lib/spec_to_pbt/type_inferrer.rb`): Infers Pbt generator code from spec definitions (e.g., `seq Element` → `Pbt.array(Pbt.integer)`).

4. **PatternCodeGenerator** (`lib/spec_to_pbt/pattern_code_generator.rb`): Maps stateless patterns to Ruby check code.

5. **StatefulGenerator** (`lib/spec_to_pbt/stateful_generator.rb`): Builds regeneration-safe stateful scaffolds and companion config files targeting `Pbt.stateful`.

### Data Structures (parser.rb)

- `Spec`: Top-level container (module_name, signatures, predicates, assertions, facts)
- `Signature`: Alloy sig (name, fields, extends)
- `Field`: Sig field (name, type, multiplicity)
- `Predicate`: Alloy pred (name, params, body)
- `Assertion`/`Fact`: Alloy assert/fact (name, body)

### Supported Patterns

The generator uses a **generic approach** - it uses the Alloy module name as the operation name in generated tests:

| Pattern | Description | Generated Code (where `op` = module name) |
|---------|-------------|-------------------------------------------|
| `idempotent` | f(f(x)) == f(x) | `result = op(input); twice = op(result); result == twice` |
| `size` | Length preservation | `output = op(input); input.length == output.length` |
| `roundtrip` | Self-inverse | `result = op(input); restored = op(result); restored == input` |
| `invariant` | Output property | `output = op(input); invariant?(output)` |

Unsupported patterns (elements, empty, ordering, etc.) are output as comments with pending tests.

### Type Mapping

| Alloy | Pbt Generator |
|-------|---------------|
| `Int` | `Pbt.integer` |
| `String` | `Pbt.string` |
| `seq X` | `Pbt.array(...)` |
| `set X` | `Pbt.array(...)` |

## Requirements

- Ruby 4.0+
- `pbt >= 0.6.0` for stateful scaffold execution

## Type Checking

This project uses [RBS inline](https://github.com/soutaro/rbs-inline) for type annotations and [Steep](https://github.com/soutaro/steep) for type checking.

- Type annotations are written inline in Ruby source files using `# @rbs` and `#:` syntax
- RBS files are generated to `sig/generated/` directory
- Steepfile configures the type checking target and library dependencies

### Annotation Syntax Examples

```ruby
# Method signatures
# @rbs name: String
# @rbs return: Array[Symbol]
def detect(name, body)

# Constants and attributes
PATTERNS = { ... }.freeze #: Hash[Symbol, Array[Regexp]]
attr_reader :spec #: Spec?

# Instance variables
@spec = nil #: Spec?

# Type aliases (inline RBS)
# @rbs!
#   type pattern_info = { predicate: Predicate, patterns: Array[Symbol] }
```

## Directory Structure

```
lib/                   # Source code (with RBS inline annotations)
sig/generated/         # Generated RBS type definitions
Steepfile              # Steep configuration

spec/fixtures/alloy/   # Test fixtures (.als files)
  sort.als
  stack.als
  queue.als
  set.als

example/               # Working examples
  impl/                # Sample implementations
    sort_impl.rb
    stack_impl.rb
  generated/           # Pre-generated PBT tests
    sort_pbt.rb
    stack_pbt.rb

generated/             # User workspace (gitignored)
  *_pbt.rb             # Generated test (require_relative "*_impl")
  *_impl.rb            # User implementation
```

Generated tests require a corresponding `*_impl.rb` file in the same directory.
For `--stateful --with-config`, durable customization belongs in `*_pbt_config.rb`.
