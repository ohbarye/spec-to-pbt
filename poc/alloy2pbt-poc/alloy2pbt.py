#!/usr/bin/env python3
"""
alloy2pbt - Convert Alloy specifications to Ruby Property-Based Tests

Usage:
    python3 alloy2pbt.py <input.als> [output.rb]

This tool parses Alloy specifications and generates Ruby PBT code
compatible with the pbt gem (https://github.com/ohbarye/pbt).
"""

import sys
import os
from alloy_parser import AlloyParser
from improved_generator import ImprovedPbtGenerator


def print_banner():
    print("""
╔═══════════════════════════════════════════════════════════╗
║                      alloy2pbt                            ║
║     Alloy Specification → Ruby Property-Based Tests       ║
╚═══════════════════════════════════════════════════════════╝
""")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None

    if not os.path.exists(input_file):
        print(f"Error: File not found: {input_file}")
        sys.exit(1)

    print_banner()
    print(f"📖 Reading: {input_file}")

    # Parse the Alloy specification
    with open(input_file) as f:
        source = f.read()

    parser = AlloyParser()
    spec = parser.parse(source)

    print(f"✓ Parsed successfully")
    print(f"  - Module: {spec.module or 'unnamed'}")
    print(f"  - Signatures: {len(spec.signatures)}")
    print(f"  - Predicates: {len(spec.predicates)}")
    print(f"  - Assertions: {len(spec.assertions)}")
    print(f"  - Facts: {len(spec.facts)}")
    print()

    # Generate PBT code
    generator = ImprovedPbtGenerator(parser.to_dict())
    pbt_code = generator.generate()

    # Show detected patterns
    print("🔍 Detected Property Patterns:")
    for name, info in generator.detected_patterns.items():
        patterns = info['patterns']
        if patterns:
            print(f"   {name}: {', '.join(patterns)}")
        else:
            print(f"   {name}: (generic)")
    print()

    # Output
    if output_file:
        with open(output_file, 'w') as f:
            f.write(pbt_code)
        print(f"✅ Generated: {output_file}")
    else:
        # Default output filename
        base = os.path.splitext(input_file)[0]
        output_file = f"{base}_pbt.rb"
        with open(output_file, 'w') as f:
            f.write(pbt_code)
        print(f"✅ Generated: {output_file}")

    print()
    print("Next steps:")
    print(f"  1. Review the generated file: {output_file}")
    print("  2. Replace placeholder implementation with your code")
    print("  3. Run: ruby {output_file}")
    print()


if __name__ == '__main__':
    main()
