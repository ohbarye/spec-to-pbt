# alloy_to_pbt

A PoC tool that generates Ruby Property-Based Tests from Alloy specifications.

## Concept

Auto-generate Property-Based Tests (PBT) from formal method specifications to automate the "spec -> implementation -> test" loop.

- Input: Alloy specification (.als)
- Output: Ruby test code compatible with [pbt gem](https://github.com/ohbarye/pbt) (.rb)

## Usage

```bash
bundle install
bin/alloy_to_pbt fixtures/sort.als
bundle exec rspec generated/sort_pbt.rb
```

## Supported Syntax

- `module`, `sig`, `pred`, `assert`, `fact`

## Detected Patterns

- roundtrip (push/pop)
- idempotent (sort(sort(x)))
- invariant (sorted)
- size (#input = #output)
- elements (permutation)

## Development

```bash
bundle exec rspec
```
