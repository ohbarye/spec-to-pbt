# alloy_to_pbt

A PoC tool that generates Ruby Property-Based Tests from Alloy specifications.

## Concept

Auto-generate Property-Based Tests (PBT) from formal method specifications to automate the "spec -> implementation -> test" loop.

- Input: Alloy specification (.als)
- Output: Ruby test code compatible with [pbt gem](https://github.com/ohbarye/pbt) (.rb)

## Usage

```bash
bundle install

# Generate PBT from Alloy spec
bin/alloy_to_pbt spec/fixtures/alloy/sort.als -o generated

# Run generated tests (requires *_impl.rb file in same directory)
bundle exec rspec generated/sort_pbt.rb
```

Generated tests require a corresponding `*_impl.rb` file:

```ruby
# generated/sort_impl.rb
def sort(array)
  array.sort
end
```

## Examples

Working examples are provided in `example/`:

```bash
# Run example tests
bundle exec rspec example/generated/sort_pbt.rb
bundle exec rspec example/generated/stack_pbt.rb
```

See `example/impl/` for sample implementations.

## Supported Alloy Syntax

- `module`, `sig`, `pred`, `assert`, `fact`

## Supported Patterns (Auto-generated)

These patterns are detected and converted to working Ruby check code:

| Pattern | Description | Example |
|---------|-------------|---------|
| idempotent | f(f(x)) == f(x) | `sort(sort(x)) == sort(x)` |
| size | Length preservation | `input.length == output.length` |
| roundtrip | Inverse operations | `push → pop → original` |
| invariant | Output property | sorted order check |

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
- No automatic inference of operation names from predicate body
- No support for stateful test sequences (only single-operation tests)
- No generation of counterexample shrinking hints
- Generated code requires manual `*_impl.rb` file

### Type Inference
- Limited to basic types: `Int`, `String`
- Custom sig types resolved by first field only
- No support for union types or complex constraints

## Development

```bash
# Run tests
bundle exec rspec

# Type checking (RBS inline + Steep)
bundle exec rbs-inline --output sig/generated lib/
bundle exec steep check
```

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
    PropertyPattern.detect
       ↓
    TypeInferrer + PatternCodeGenerator
       ↓
    unified.erb template
       ↓
    Ruby PBT code (.rb)
```

See [CLAUDE.md](CLAUDE.md) for detailed architecture documentation.
