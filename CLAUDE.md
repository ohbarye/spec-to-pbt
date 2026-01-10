# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

alloy_to_pbt is a tool that generates Ruby Property-Based Tests from Alloy specifications. It parses .als files (Alloy specification language) and outputs Ruby test code compatible with the pbt gem.

The generator uses a **pattern-based unified approach** - instead of domain-specific templates, it detects property patterns and dynamically generates check code.

## Commands

```bash
# Install dependencies
bundle install

# Run all tests
bundle exec rspec

# Run a single test file
bundle exec rspec spec/alloy_to_pbt/parser_spec.rb

# Run a specific test (by line number)
bundle exec rspec spec/alloy_to_pbt/parser_spec.rb:14

# Generate PBT from Alloy spec
bin/alloy_to_pbt fixtures/sort.als
bin/alloy_to_pbt fixtures/stack.als -o output_dir

# Run generated tests (requires *_impl.rb file)
bundle exec rspec generated/sort_pbt.rb
```

## Architecture

```
Alloy Spec (.als)
       ↓
    Parser
       ↓
    Spec { signatures, predicates, ... }
       ↓
    PropertyPattern.detect → [:idempotent, :size, ...]
       ↓
    TypeInferrer → Pbt.array(Pbt.integer)
       ↓
    PatternCodeGenerator → Ruby check code
       ↓
    Generator + unified.erb
       ↓
    Ruby PBT code (.rb)
```

### Core Components

1. **Parser** (`lib/alloy_to_pbt/parser.rb`): Parses Alloy .als files using regex patterns. Outputs a `Spec` data structure containing signatures, predicates, assertions, and facts.

2. **PropertyPattern** (`lib/alloy_to_pbt/property_pattern.rb`): Detects common property patterns from predicate names and bodies using regex matching.

3. **TypeInferrer** (`lib/alloy_to_pbt/type_inferrer.rb`): Infers Pbt generator code from Alloy sig definitions (e.g., `seq Element` → `Pbt.array(Pbt.integer)`).

4. **PatternCodeGenerator** (`lib/alloy_to_pbt/pattern_code_generator.rb`): Maps detected patterns to Ruby check code (e.g., `:idempotent` → `sort(sort(x)) == sort(x)`).

5. **Generator** (`lib/alloy_to_pbt/generator.rb`): Orchestrates the pipeline and renders Ruby PBT code using `unified.erb`.

### Data Structures (parser.rb)

- `Spec`: Top-level container (module_name, signatures, predicates, assertions, facts)
- `Signature`: Alloy sig (name, fields, extends)
- `Field`: Sig field (name, type, multiplicity)
- `Predicate`: Alloy pred (name, params, body)
- `Assertion`/`Fact`: Alloy assert/fact (name, body)

### Supported Patterns

| Pattern | Description | Generated Check |
|---------|-------------|-----------------|
| `idempotent` | f(f(x)) == f(x) | `sort(sort(x)) == sort(x)` |
| `size` | Length preservation | `input.length == output.length` |
| `roundtrip` | Inverse operations | `push → pop → original` |
| `invariant` | Output property | `output.each_cons(2).all? { \|a, b\| a <= b }` |

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
- pbt gem for property-based testing

## Generated Code Structure

Generated tests require a corresponding `*_impl.rb` file with the implementation:

```
generated/
  sort_pbt.rb      # Generated test (require_relative "sort_impl")
  sort_impl.rb     # User implementation (def sort(array) ... end)
```
