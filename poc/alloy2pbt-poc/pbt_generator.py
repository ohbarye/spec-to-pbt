#!/usr/bin/env python3
"""
Alloy to Ruby PBT (pbt gem) code generator
Converts parsed Alloy specifications to property-based tests
"""

import json
import re
from dataclasses import dataclass
from typing import Optional
from alloy_parser import AlloyParser


@dataclass
class TypeMapping:
    """Maps Alloy types to Ruby PBT arbitraries"""

    # Basic type mappings
    BASIC_TYPES = {
        'Int': 'Pbt.integer',
        'String': 'Pbt.ascii_string',
        'Bool': 'Pbt.boolean',
    }

    @classmethod
    def to_arbitrary(cls, alloy_type: str, multiplicity: str = 'one') -> str:
        """Convert Alloy type to PBT arbitrary"""
        base = cls.BASIC_TYPES.get(alloy_type, f'arbitrary_{alloy_type.lower()}')

        if multiplicity == 'seq':
            return f'Pbt.array({base})'
        elif multiplicity == 'set':
            return f'Pbt.array({base}).map {{ |arr| arr.uniq }}'
        elif multiplicity == 'lone':
            return f'Pbt.one_of({base}, Pbt.constant(nil))'
        else:  # 'one'
            return base


class AlloyExpressionTranslator:
    """Translates Alloy expressions to Ruby code"""

    def translate(self, expr: str, context: dict) -> str:
        """
        Translate Alloy expression to Ruby.
        context: { param_name: ruby_var_name }
        """
        ruby_code = expr

        # Replace Alloy operators with Ruby
        translations = [
            # Logical operators
            (r'\band\b', '&&'),
            (r'\bor\b', '||'),
            (r'\bnot\b', '!'),
            (r'\bimplies\b', '? true :'),  # Simplified implication
            (r'\biff\b', '=='),

            # Quantifiers (simplified)
            (r'all\s+(\w+)\s*:\s*Int\s*\|', r'(0...(input.length)).all? { |\1|'),

            # Alloy functions
            (r'#(\w+(?:\.\w+)*)', r'\1.length'),  # Cardinality
            (r'sub\[([^,]+),\s*([^\]]+)\]', r'(\1 - \2)'),  # Subtraction
            (r'add\[([^,]+),\s*([^\]]+)\]', r'(\1 + \2)'),  # Addition

            # Field access adjustments
            (r'\.elements\[(\w+)\]\.value', r'[\1]'),  # List element access
            (r'\.elements\.elems', '.sort'),  # Element set
            (r'\.elements', ''),  # Remove .elements for direct array

            # Comparison
            (r'>=', '>='),
            (r'<=', '<='),
            (r'!=', '!='),
        ]

        for pattern, replacement in translations:
            ruby_code = re.sub(pattern, replacement, ruby_code)

        # Replace parameter references with Ruby variables
        for alloy_param, ruby_var in context.items():
            ruby_code = re.sub(rf'\b{alloy_param}\b', ruby_var, ruby_code)

        return ruby_code


class PbtGenerator:
    """Generates Ruby PBT code from parsed Alloy specification"""

    def __init__(self, spec: dict):
        self.spec = spec
        self.translator = AlloyExpressionTranslator()

    def generate(self) -> str:
        """Generate complete Ruby PBT test file"""
        lines = [
            '# frozen_string_literal: true',
            '',
            '# Auto-generated from Alloy specification',
            f'# Module: {self.spec.get("module", "unknown")}',
            '',
            'require "pbt"',
            '',
        ]

        # Generate helper comment about what the spec defines
        lines.append('# === Alloy Specification Summary ===')
        lines.append('#')
        for sig in self.spec.get('signatures', []):
            lines.append(f'# Signature: {sig["name"]}')
            for field in sig.get('fields', []):
                lines.append(f'#   - {field["name"]}: {field["multiplicity"]} {field["type"]}')
        lines.append('#')
        for pred in self.spec.get('predicates', []):
            params = ', '.join(p['name'] for p in pred.get('params', []))
            lines.append(f'# Predicate: {pred["name"]}[{params}]')
        for assertion in self.spec.get('assertions', []):
            lines.append(f'# Assertion: {assertion["name"]}')
        lines.append('')

        # Generate arbitrary for the main type
        lines.extend(self._generate_arbitrary())
        lines.append('')

        # Generate properties from predicates
        lines.extend(self._generate_properties())

        return '\n'.join(lines)

    def _generate_arbitrary(self) -> list[str]:
        """Generate arbitrary definitions based on signatures"""
        lines = ['# === Arbitrary Definitions ===', '']

        # For this example, we're focusing on List of Integers
        # In a full implementation, we'd generate arbitraries for all signatures
        lines.append('# Arbitrary for input: Array of Integers')
        lines.append('INPUT_ARBITRARY = Pbt.array(Pbt.integer)')
        lines.append('')

        return lines

    def _generate_properties(self) -> list[str]:
        """Generate property tests from predicates and assertions"""
        lines = ['# === Property Tests ===', '']

        # Generate a test block
        lines.append('Pbt.assert do')

        # Main property combining all predicates
        lines.append('  Pbt.property(INPUT_ARBITRARY) do |input|')
        lines.append('    # Apply the function under test')
        lines.append('    output = sort(input)  # Replace with your implementation')
        lines.append('')

        # Generate checks from predicates
        for pred in self.spec.get('predicates', []):
            lines.extend(self._generate_predicate_check(pred))

        lines.append('  end')
        lines.append('end')

        return lines

    def _generate_predicate_check(self, pred: dict) -> list[str]:
        """Generate Ruby check from Alloy predicate"""
        lines = []
        name = pred['name']
        body = pred['body']
        params = pred.get('params', [])

        lines.append(f'    # Property: {name}')

        # Determine context based on parameters
        context = {}
        if len(params) == 1:
            context[params[0]['name']] = 'output'
        elif len(params) == 2:
            context[params[0]['name']] = 'input'
            context[params[1]['name']] = 'output'

        # Translate the body to Ruby
        ruby_check = self._translate_predicate_body(name, body, context)

        if ruby_check:
            lines.append(f'    raise "{name} failed" unless {ruby_check}')
            lines.append('')

        return lines

    def _translate_predicate_body(self, name: str, body: str, context: dict) -> Optional[str]:
        """Translate predicate body to Ruby boolean expression"""

        # Handle specific known patterns
        if 'Sorted' in name:
            return 'output.each_cons(2).all? { |a, b| a <= b }'

        if 'LengthPreserved' in name:
            return 'input.length == output.length'

        if 'SameElements' in name:
            return 'input.sort == output.sort'

        if 'Idempotent' in name:
            return 'sort(output) == output'

        # Generic translation (may need manual adjustment)
        return self.translator.translate(body, context)


def generate_pbt_from_alloy(alloy_file: str) -> str:
    """Main function to generate PBT from Alloy file"""
    with open(alloy_file) as f:
        source = f.read()

    parser = AlloyParser()
    parser.parse(source)

    generator = PbtGenerator(parser.to_dict())
    return generator.generate()


if __name__ == '__main__':
    import sys

    filename = sys.argv[1] if len(sys.argv) > 1 else 'sort.als'
    pbt_code = generate_pbt_from_alloy(filename)

    print(pbt_code)
