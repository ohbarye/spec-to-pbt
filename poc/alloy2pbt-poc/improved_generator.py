#!/usr/bin/env python3
"""
Improved Alloy to Ruby PBT generator with property pattern recognition
"""

import json
import re
from dataclasses import dataclass
from typing import Optional, List, Dict
from alloy_parser import AlloyParser


class PropertyPattern:
    """Recognizes common property patterns in Alloy predicates"""

    PATTERNS = {
        # Pattern: round-trip / inverse
        'roundtrip': [
            r'push.*pop|pop.*push',
            r'encode.*decode|decode.*encode',
            r'serialize.*deserialize',
            r'add.*remove|remove.*add',
        ],
        # Pattern: idempotent
        'idempotent': [
            r'(\w+)\[.*\]\s*=\s*\1\[',
            r'idempotent',
            r'twice|same.*result',
        ],
        # Pattern: invariant preservation
        'invariant': [
            r'sorted|ordered',
            r'valid|invariant',
            r'preserved|maintained',
        ],
        # Pattern: size/length related
        'size': [
            r'#\w+.*=.*#\w+',
            r'length|size|count',
            r'add\[.*1\]|sub\[.*1\]',
        ],
        # Pattern: element preservation
        'elements': [
            r'elems\s*=\s*elems',
            r'same.*elements',
            r'permutation',
        ],
        # Pattern: emptiness check
        'empty': [
            r'#\w+\s*=\s*0',
            r'empty|nil|none',
        ],
        # Pattern: LIFO/FIFO
        'ordering': [
            r'lifo|fifo',
            r'first.*last|last.*first',
            r'head|tail|front|back',
        ],
    }

    @classmethod
    def detect(cls, name: str, body: str) -> List[str]:
        """Detect which patterns apply to this predicate"""
        detected = []
        text = (name + ' ' + body).lower()

        for pattern_name, regexes in cls.PATTERNS.items():
            for regex in regexes:
                if re.search(regex, text, re.IGNORECASE):
                    detected.append(pattern_name)
                    break

        return detected


class RubyCodeGenerator:
    """Generates Ruby code from detected patterns"""

    PATTERN_TEMPLATES = {
        'sorted': '''
    # Property: Output is sorted
    raise "Not sorted" unless output.each_cons(2).all? { |a, b| a <= b }
''',
        'length_preserved': '''
    # Property: Length preserved
    raise "Length changed" unless input.length == output.length
''',
        'elements_preserved': '''
    # Property: Same elements (permutation)
    raise "Elements differ" unless input.sort == output.sort
''',
        'idempotent': '''
    # Property: Idempotent (applying twice gives same result)
    raise "Not idempotent" unless {func}(output) == output
''',
        'roundtrip': '''
    # Property: Round-trip (inverse operations)
    raise "Round-trip failed" unless {func_inverse}({func}(input)) == input
''',
        'push_adds': '''
    # Property: Push increases size by 1
    original_size = stack.length
    stack.push(element)
    raise "Push failed" unless stack.length == original_size + 1
''',
        'pop_removes': '''
    # Property: Pop decreases size by 1 (if not empty)
    unless stack.empty?
      original_size = stack.length
      stack.pop
      raise "Pop failed" unless stack.length == original_size - 1
    end
''',
        'push_pop_identity': '''
    # Property: Push then Pop returns to original state
    original = stack.dup
    element = stack.push(arbitrary_element)
    stack.pop
    raise "Push-Pop identity failed" unless stack == original
''',
        'lifo': '''
    # Property: LIFO - Last pushed is first popped
    stack.push(element)
    raise "LIFO violated" unless stack.pop == element
''',
    }


class ImprovedPbtGenerator:
    """Generates Ruby PBT code with pattern recognition"""

    def __init__(self, spec: dict):
        self.spec = spec
        self.detected_patterns = {}

    def analyze(self):
        """Analyze predicates and detect patterns"""
        for pred in self.spec.get('predicates', []):
            patterns = PropertyPattern.detect(pred['name'], pred['body'])
            self.detected_patterns[pred['name']] = {
                'predicate': pred,
                'patterns': patterns,
            }

    def generate(self) -> str:
        """Generate Ruby PBT code"""
        self.analyze()

        lines = [
            '# frozen_string_literal: true',
            '',
            '# Auto-generated Property-Based Tests from Alloy Specification',
            f'# Module: {self.spec.get("module", "unknown")}',
            '#',
            '# Detected Property Patterns:',
        ]

        # Document detected patterns
        for name, info in self.detected_patterns.items():
            patterns_str = ', '.join(info['patterns']) or 'generic'
            lines.append(f'#   {name}: [{patterns_str}]')

        lines.extend([
            '',
            'require "pbt"',
            '',
            '# =================================================',
            '# Implementation placeholder - replace with your code',
            '# =================================================',
            '',
        ])

        # Generate implementation stubs based on module type
        lines.extend(self._generate_implementation_stubs())

        lines.extend([
            '',
            '# =================================================',
            '# Property-Based Tests',
            '# =================================================',
            '',
        ])

        # Generate tests based on module type
        module_name = self.spec.get('module', '').lower()

        if 'sort' in module_name:
            lines.extend(self._generate_sort_tests())
        elif 'stack' in module_name:
            lines.extend(self._generate_stack_tests())
        else:
            lines.extend(self._generate_generic_tests())

        return '\n'.join(lines)

    def _generate_implementation_stubs(self) -> List[str]:
        """Generate placeholder implementations"""
        module_name = self.spec.get('module', '').lower()

        if 'sort' in module_name:
            return [
                'def sort(array)',
                '  # TODO: Replace with your implementation',
                '  array.sort',
                'end',
            ]
        elif 'stack' in module_name:
            return [
                'class Stack',
                '  def initialize',
                '    @elements = []',
                '  end',
                '',
                '  def push(element)',
                '    @elements.push(element)',
                '    self',
                '  end',
                '',
                '  def pop',
                '    @elements.pop',
                '  end',
                '',
                '  def peek',
                '    @elements.last',
                '  end',
                '',
                '  def empty?',
                '    @elements.empty?',
                '  end',
                '',
                '  def length',
                '    @elements.length',
                '  end',
                '',
                '  def ==(other)',
                '    @elements == other.instance_variable_get(:@elements)',
                '  end',
                '',
                '  def dup',
                '    s = Stack.new',
                '    @elements.each { |e| s.push(e) }',
                '    s',
                '  end',
                'end',
            ]
        else:
            return ['# Add your implementation here']

    def _generate_sort_tests(self) -> List[str]:
        """Generate tests for sorting"""
        return [
            'describe "Sort Properties" do',
            '  Pbt.assert do',
            '    Pbt.property(Pbt.array(Pbt.integer)) do |input|',
            '      output = sort(input)',
            '',
            '      # Property 1: Sorted - output is in ascending order',
            '      unless output.each_cons(2).all? { |a, b| a <= b }',
            '        raise "Sorted property failed: #{output.inspect}"',
            '      end',
            '',
            '      # Property 2: LengthPreserved - same number of elements',
            '      unless input.length == output.length',
            '        raise "LengthPreserved failed: #{input.length} != #{output.length}"',
            '      end',
            '',
            '      # Property 3: SameElements - output is a permutation of input',
            '      unless input.sort == output.sort',
            '        raise "SameElements failed: elements differ"',
            '      end',
            '',
            '      # Property 4: Idempotent - sorting a sorted array gives same result',
            '      unless sort(output) == output',
            '        raise "Idempotent failed: sort(sort(x)) != sort(x)"',
            '      end',
            '    end',
            '  end',
            'end',
        ]

    def _generate_stack_tests(self) -> List[str]:
        """Generate tests for stack"""
        return [
            'describe "Stack Properties" do',
            '  # Test: Push increases size',
            '  Pbt.assert do',
            '    Pbt.property(Pbt.array(Pbt.integer), Pbt.integer) do |initial, element|',
            '      stack = Stack.new',
            '      initial.each { |e| stack.push(e) }',
            '      ',
            '      original_length = stack.length',
            '      stack.push(element)',
            '      ',
            '      unless stack.length == original_length + 1',
            '        raise "PushAddsElement failed"',
            '      end',
            '    end',
            '  end',
            '',
            '  # Test: Pop decreases size (when not empty)',
            '  Pbt.assert do',
            '    Pbt.property(Pbt.array(Pbt.integer, min: 1)) do |initial|',
            '      stack = Stack.new',
            '      initial.each { |e| stack.push(e) }',
            '      ',
            '      original_length = stack.length',
            '      stack.pop',
            '      ',
            '      unless stack.length == original_length - 1',
            '        raise "PopRemovesElement failed"',
            '      end',
            '    end',
            '  end',
            '',
            '  # Test: LIFO - Last In First Out',
            '  Pbt.assert do',
            '    Pbt.property(Pbt.array(Pbt.integer), Pbt.integer) do |initial, element|',
            '      stack = Stack.new',
            '      initial.each { |e| stack.push(e) }',
            '      ',
            '      stack.push(element)',
            '      popped = stack.pop',
            '      ',
            '      unless popped == element',
            '        raise "LIFO failed: pushed #{element}, popped #{popped}"',
            '      end',
            '    end',
            '  end',
            '',
            '  # Test: Push-Pop identity (round trip)',
            '  Pbt.assert do',
            '    Pbt.property(Pbt.array(Pbt.integer), Pbt.integer) do |initial, element|',
            '      stack = Stack.new',
            '      initial.each { |e| stack.push(e) }',
            '      original_length = stack.length',
            '      ',
            '      stack.push(element)',
            '      stack.pop',
            '      ',
            '      unless stack.length == original_length',
            '        raise "PushPopIdentity failed"',
            '      end',
            '    end',
            '  end',
            'end',
        ]

    def _generate_generic_tests(self) -> List[str]:
        """Generate generic tests from predicates"""
        lines = ['describe "Properties" do']

        for pred in self.spec.get('predicates', []):
            name = pred['name']
            body = pred['body']
            lines.extend([
                f'  # Predicate: {name}',
                f'  # Original: {body}',
                '  Pbt.assert do',
                '    Pbt.property(Pbt.integer) do |input|',
                f'      # TODO: Implement check for {name}',
                '      true',
                '    end',
                '  end',
                '',
            ])

        lines.append('end')
        return lines


def main():
    import sys

    filename = sys.argv[1] if len(sys.argv) > 1 else 'sort.als'

    with open(filename) as f:
        source = f.read()

    parser = AlloyParser()
    parser.parse(source)

    generator = ImprovedPbtGenerator(parser.to_dict())
    print(generator.generate())


if __name__ == '__main__':
    main()
