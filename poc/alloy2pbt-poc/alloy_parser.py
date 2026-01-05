#!/usr/bin/env python3
"""
Simple Alloy specification parser - Proof of Concept
Parses a subset of Alloy syntax and outputs JSON
"""

import re
import json
from dataclasses import dataclass, field, asdict
from typing import Optional


@dataclass
class Field:
    name: str
    type: str
    multiplicity: str = "one"


@dataclass
class Signature:
    name: str
    fields: list[Field] = field(default_factory=list)
    extends: Optional[str] = None
    multiplicity: Optional[str] = None


@dataclass
class Predicate:
    name: str
    params: list[dict] = field(default_factory=list)
    body: str = ""


@dataclass
class Assertion:
    name: str
    body: str = ""


@dataclass
class Fact:
    name: Optional[str]
    body: str = ""


@dataclass
class AlloySpec:
    module: Optional[str] = None
    signatures: list[Signature] = field(default_factory=list)
    predicates: list[Predicate] = field(default_factory=list)
    assertions: list[Assertion] = field(default_factory=list)
    facts: list[Fact] = field(default_factory=list)


class AlloyParser:
    def __init__(self):
        self.spec = AlloySpec()

    def parse(self, source: str) -> AlloySpec:
        # Remove comments
        source = re.sub(r'--.*$', '', source, flags=re.MULTILINE)
        source = re.sub(r'//.*$', '', source, flags=re.MULTILINE)
        source = re.sub(r'/\*.*?\*/', '', source, flags=re.DOTALL)

        # Parse module name
        self._parse_module(source)

        # Parse signatures
        self._parse_signatures(source)

        # Parse predicates
        self._parse_predicates(source)

        # Parse assertions
        self._parse_assertions(source)

        # Parse facts
        self._parse_facts(source)

        return self.spec

    def _parse_module(self, source: str):
        match = re.search(r'module\s+(\w+)', source)
        if match:
            self.spec.module = match.group(1)

    def _parse_signatures(self, source: str):
        # Match: sig Name { field: type, ... }
        # Also handle: sig Name extends Parent { ... }
        sig_pattern = r'sig\s+(\w+)(?:\s+extends\s+(\w+))?\s*\{([^}]*)\}'

        for match in re.finditer(sig_pattern, source, re.DOTALL):
            name = match.group(1)
            extends = match.group(2)
            fields_str = match.group(3)
            fields = self._parse_fields(fields_str)
            self.spec.signatures.append(
                Signature(name=name, fields=fields, extends=extends)
            )

    def _parse_fields(self, fields_str: str) -> list[Field]:
        fields = []
        # Match: fieldName: multiplicity Type
        field_pattern = r'(\w+)\s*:\s*(one|lone|set|seq)?\s*(\w+)'

        for match in re.finditer(field_pattern, fields_str):
            field_name = match.group(1)
            multiplicity = match.group(2) or 'one'
            field_type = match.group(3)
            fields.append(Field(
                name=field_name,
                type=field_type,
                multiplicity=multiplicity
            ))

        return fields

    def _parse_predicates(self, source: str):
        # Match: pred Name[params] { body }
        pred_pattern = r'pred\s+(\w+)\s*\[([^\]]*)\]\s*\{([^}]*)\}'

        for match in re.finditer(pred_pattern, source, re.DOTALL):
            name = match.group(1)
            params_str = match.group(2)
            body = match.group(3).strip()
            params = self._parse_params(params_str)
            self.spec.predicates.append(
                Predicate(name=name, params=params, body=body)
            )

    def _parse_params(self, params_str: str) -> list[dict]:
        params = []
        # Match: name: Type or name, name2: Type
        param_pattern = r'([\w,\s]+)\s*:\s*(\w+)'

        for match in re.finditer(param_pattern, params_str):
            names = [n.strip() for n in match.group(1).split(',')]
            param_type = match.group(2)
            for name in names:
                if name:
                    params.append({'name': name, 'type': param_type})

        return params

    def _parse_assertions(self, source: str):
        # Match: assert Name { body }
        assert_pattern = r'assert\s+(\w+)\s*\{([^}]*)\}'

        for match in re.finditer(assert_pattern, source, re.DOTALL):
            name = match.group(1)
            body = match.group(2).strip()
            self.spec.assertions.append(
                Assertion(name=name, body=body)
            )

    def _parse_facts(self, source: str):
        # Match: fact Name { body } or fact { body }
        fact_pattern = r'fact\s*(\w*)\s*\{([^}]*)\}'

        for match in re.finditer(fact_pattern, source, re.DOTALL):
            name = match.group(1) or None
            body = match.group(2).strip()
            self.spec.facts.append(
                Fact(name=name, body=body)
            )

    def to_dict(self) -> dict:
        return {
            'module': self.spec.module,
            'signatures': [
                {
                    'name': s.name,
                    'extends': s.extends,
                    'fields': [asdict(f) for f in s.fields]
                }
                for s in self.spec.signatures
            ],
            'predicates': [
                {
                    'name': p.name,
                    'params': p.params,
                    'body': p.body
                }
                for p in self.spec.predicates
            ],
            'assertions': [
                {
                    'name': a.name,
                    'body': a.body
                }
                for a in self.spec.assertions
            ],
            'facts': [
                {
                    'name': f.name,
                    'body': f.body
                }
                for f in self.spec.facts
            ]
        }

    def to_json(self) -> str:
        return json.dumps(self.to_dict(), indent=2)


if __name__ == '__main__':
    import sys

    filename = sys.argv[1] if len(sys.argv) > 1 else 'sort.als'

    with open(filename) as f:
        source = f.read()

    parser = AlloyParser()
    parser.parse(source)

    print("=== Parsed Alloy Specification ===")
    print(parser.to_json())
