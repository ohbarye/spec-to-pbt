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

```bash
# Install dependencies
bundle install

# Run all tests
bundle exec rspec

# Run a single test file
bundle exec rspec spec/spec_to_pbt/parser_spec.rb

# Run a specific test (by line number)
bundle exec rspec spec/spec_to_pbt/parser_spec.rb:14

# Generate PBT from Alloy spec
bin/spec_to_pbt spec/fixtures/alloy/sort.als
bin/spec_to_pbt spec/fixtures/alloy/stack.als -o output_dir

# Generate stateful scaffold with config
bin/spec_to_pbt spec/fixtures/alloy/stack.als --stateful --with-config -o generated

# Run generated tests (requires *_impl.rb file)
bundle exec rspec generated/sort_pbt.rb

# Run stateful example tests
env ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec example/stateful/stack_pbt.rb

# Type checking with Steep
bundle exec rbs-inline --output sig/generated lib/  # Generate RBS from inline annotations
bundle exec steep check                               # Run type check
```

> If you use [mise](https://mise.jdx.dev/) to manage your Ruby toolchain, prefix commands with `mise exec --`.

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
    +-------------------------------+------------------------------------------+
    | stateless path                | stateful path                            |
    |                               |                                          |
    | PropertyPattern.detect        | StatefulPredicateAnalyzer                |
    | TypeInferrer                  | GuardInferencer / GuardAnalysis          |
    | PatternCodeGenerator          | StateUpdateInferencer                    |
    |                               | RelatedHintAnalyzer                      |
    |                               | StatefulGenerator                        |
    |                               |   +-- CommandPlan                        |
    |                               |   +-- StateShapeInspector                |
    |                               |   +-- InitialStateInferencer             |
    |                               |   +-- ProjectionPlan                     |
    |                               |   +-- ConfigRenderer                     |
    |                               |   +-- VerifyRenderer                     |
    |                               |   +-- SupportModuleRenderer              |
    |                               |   +-- SuggestionRenderer                 |
    +-------------------------------+------------------------------------------+
       |
    Ruby PBT code (.rb)
```

### Core Components

1. **Frontends** (`lib/spec_to_pbt/frontends/`): Loads Alloy and experimental Quint inputs into a frontend-neutral document model via dedicated parsers and adapters.

2. **Core::SpecDocument** (`lib/spec_to_pbt/core.rb`): Frontend-neutral document model that both stateless and stateful paths consume.

3. **PropertyPattern** (`lib/spec_to_pbt/property_pattern.rb`): Detects common stateless property patterns from predicate names and bodies.

4. **TypeInferrer** (`lib/spec_to_pbt/type_inferrer.rb`): Infers Pbt generator code from spec definitions (e.g., `seq Element` -> `Pbt.array(Pbt.integer)`).

5. **PatternCodeGenerator** (`lib/spec_to_pbt/pattern_code_generator.rb`): Maps stateless patterns to Ruby check code.

6. **StatefulPredicateAnalyzer** (`lib/spec_to_pbt/stateful_predicate_analyzer.rb`): Analyzes spec predicates to extract commands, state shapes, transitions, and guards for stateful scaffold generation.

7. **GuardInferencer** (`lib/spec_to_pbt/guard_inferencer.rb`): Infers guard conditions from spec predicates. Produces **GuardAnalysis** (`lib/spec_to_pbt/guard_analysis.rb`) results.

8. **StateUpdateInferencer** (`lib/spec_to_pbt/state_update_inferencer.rb`): Infers state update patterns (collection mutation, scalar mutation, paired counters, etc.) from predicate bodies.

9. **RelatedHintAnalyzer** (`lib/spec_to_pbt/related_hint_analyzer.rb`): Extracts related assertions, facts, and property predicates to include as hints in the generated scaffold.

10. **StatefulGenerator** (`lib/spec_to_pbt/stateful_generator.rb`): Orchestrates stateful scaffold generation, delegating to sub-components:
    - **CommandPlan** (`lib/spec_to_pbt/stateful_generator/command_plan.rb`): Plans per-command generation (arguments, applicable?, next_state, run!, verify!).
    - **StateShapeInspector** (`lib/spec_to_pbt/stateful_generator/state_shape_inspector.rb`): Inspects and classifies state shape (scalar, hash, collection, projection).
    - **InitialStateInferencer** (`lib/spec_to_pbt/stateful_generator/initial_state_inferencer.rb`): Infers initial model state from spec constraints.
    - **ProjectionPlan** (`lib/spec_to_pbt/stateful_generator/projection_plan.rb`): Plans append-only collection + projected scalar generation.
    - **ConfigRenderer** (`lib/spec_to_pbt/stateful_generator/config_renderer.rb`): Renders `*_pbt_config.rb` with field-aware suggestions.
    - **VerifyRenderer** (`lib/spec_to_pbt/stateful_generator/verify_renderer.rb`): Renders per-command verify! logic with safe executable checks.
    - **SupportModuleRenderer** (`lib/spec_to_pbt/stateful_generator/support_module_renderer.rb`): Renders helper modules included in the generated scaffold.
    - **SuggestionRenderer** (`lib/spec_to_pbt/stateful_generator/suggestion_renderer.rb`): Renders inline code comments with analyzer-driven hints.

### Data Structures (parser.rb)

- `Spec`: Top-level container (module_name, signatures, predicates, assertions, facts)
- `Signature`: Alloy sig (name, fields, extends)
- `Field`: Sig field (name, type, multiplicity)
- `Predicate`: Alloy pred (name, params, body)
- `Assertion`/`Fact`: Alloy assert/fact (name, body)

### Supported Stateless Patterns

| Pattern | Description | Generated Code (where `op` = module name) |
|---------|-------------|-------------------------------------------|
| `idempotent` | f(f(x)) == f(x) | `result = op(input); twice = op(result); result == twice` |
| `size` | Length preservation | `output = op(input); input.length == output.length` |
| `roundtrip` | Self-inverse | `result = op(input); restored = op(result); restored == input` |
| `invariant` | Output property | `output = op(input); invariant?(output)` |

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

## Directory Structure

```
lib/spec_to_pbt/
  core.rb                          # Frontend-neutral SpecDocument model
  frontends/                       # Alloy and Quint parsers + adapters
  parser.rb                        # Legacy Alloy parser (data structures)
  property_pattern.rb              # Stateless pattern detection
  type_inferrer.rb                 # Alloy type -> Pbt generator mapping
  pattern_code_generator.rb        # Stateless pattern -> Ruby code
  stateful_predicate_analyzer.rb   # Spec -> command/state analysis
  guard_inferencer.rb              # Guard condition inference
  guard_analysis.rb                # Guard analysis result types
  state_update_inferencer.rb       # State update pattern inference
  related_hint_analyzer.rb         # Assertion/fact hint extraction
  stateful_generator.rb            # Stateful scaffold orchestrator
  stateful_generator/
    command_plan.rb                # Per-command generation plan
    state_shape_inspector.rb       # State shape classification
    initial_state_inferencer.rb    # Initial state inference
    projection_plan.rb             # Append-only + projection plan
    config_renderer.rb             # Config file rendering
    verify_renderer.rb             # Verify logic rendering
    support_module_renderer.rb     # Helper module rendering
    suggestion_renderer.rb         # Inline hint rendering
  stateful_config_name.rb          # Config naming conventions
  generator.rb                     # Top-level generation entry point
  templates/                       # ERB templates
  version.rb

sig/generated/                     # Generated RBS type definitions
Steepfile                          # Steep configuration

spec/fixtures/alloy/               # Alloy test fixtures (.als)
spec/fixtures/quint/               # Quint test fixtures (.qnt)

example/
  impl/                            # Sample implementations
  stateful/                        # Config-aware stateful examples (24+ domains)
  generated/                       # Pre-generated PBT tests

generated/                         # User workspace (gitignored)
  *_pbt.rb                         # Generated test
  *_pbt_config.rb                  # User-owned config (with --with-config)
  *_impl.rb                        # User-owned implementation
```
