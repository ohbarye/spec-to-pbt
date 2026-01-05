# CLAUDE.md - AI Agent Context

## Project: alloy2pbt

Convert Alloy formal specifications to Ruby Property-Based Tests (pbt gem).

## Current Status

- **Phase**: POC completed
- **Next**: Full implementation with Alloy Java API

## Key Decisions Made

1. **Use Alloy** (not TLA+, not custom DSL) as the specification language
2. **Target pbt gem** (https://github.com/ohbarye/pbt) for generated tests
3. **Avoid creating new DSLs** - leverage existing formal methods ecosystem

## Architecture

```
Alloy Spec (.als)
    ↓ parse
AST (JSON/dict)
    ↓ pattern detection
Property patterns (invariant, roundtrip, idempotent, etc.)
    ↓ generate
Ruby PBT code (pbt gem compatible)
```

## Files to Know

| File | Purpose |
|------|---------|
| `alloy_parser.py` | Parses Alloy syntax to dict/JSON |
| `improved_generator.py` | Pattern detection + code generation |
| `alloy2pbt.py` | CLI entry point |
| `HANDOFF.md` | Detailed handoff documentation |

## Commands

```bash
# Generate PBT from Alloy spec
python3 alloy2pbt.py input.als output.rb

# Run the parser only
python3 alloy_parser.py input.als
```

## What Needs to Be Done

1. **Replace simple parser with Alloy Java API**
   - Current parser is regex-based, limited
   - Need to call Alloy JAR for proper AST

2. **Port to Ruby gem**
   - Package as `gem install alloy2pbt`
   - Integrate with pbt gem

3. **Add TLA+ support** (optional)
   - Via Apalache JSON output

## Owner Context

- Author of pbt gem
- Familiar with PBT, new to formal methods
- Prefers practical solutions over theoretical completeness

## Don't Do

- Create new DSL/specification format
- Deep dive into formal methods theory
- Prioritize TLA+ over Alloy (start with Alloy)
