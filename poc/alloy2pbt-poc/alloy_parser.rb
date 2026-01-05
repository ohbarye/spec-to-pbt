#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple Alloy specification parser
# This is a proof-of-concept that parses a subset of Alloy syntax

module AlloyParser
  class Signature
    attr_reader :name, :fields, :multiplicity

    def initialize(name, fields: {}, multiplicity: nil)
      @name = name
      @fields = fields # { field_name => { type:, multiplicity: } }
      @multiplicity = multiplicity
    end

    def to_h
      {
        type: 'signature',
        name: @name,
        fields: @fields,
        multiplicity: @multiplicity
      }
    end
  end

  class Predicate
    attr_reader :name, :params, :body

    def initialize(name, params: [], body: '')
      @name = name
      @params = params # [{ name:, type: }]
      @body = body
    end

    def to_h
      {
        type: 'predicate',
        name: @name,
        params: @params,
        body: @body
      }
    end
  end

  class Assertion
    attr_reader :name, :body

    def initialize(name, body: '')
      @name = name
      @body = body
    end

    def to_h
      {
        type: 'assertion',
        name: @name,
        body: @body
      }
    end
  end

  class Parser
    attr_reader :signatures, :predicates, :assertions, :facts

    def initialize
      @signatures = []
      @predicates = []
      @assertions = []
      @facts = []
    end

    def parse(source)
      # Remove comments
      source = source.gsub(/--.*$/, '')
      source = source.gsub(/\/\/.*$/, '')
      source = source.gsub(/\/\*.*?\*\//m, '')

      # Parse signatures
      parse_signatures(source)

      # Parse predicates
      parse_predicates(source)

      # Parse assertions
      parse_assertions(source)

      # Parse facts
      parse_facts(source)

      self
    end

    def to_h
      {
        signatures: @signatures.map(&:to_h),
        predicates: @predicates.map(&:to_h),
        assertions: @assertions.map(&:to_h),
        facts: @facts
      }
    end

    def to_json
      require 'json'
      JSON.pretty_generate(to_h)
    end

    private

    def parse_signatures(source)
      # Match: sig Name { field: type, ... }
      sig_pattern = /sig\s+(\w+)\s*\{([^}]*)\}/m

      source.scan(sig_pattern) do |match|
        name = match[0]
        fields_str = match[1]
        fields = parse_fields(fields_str)
        @signatures << Signature.new(name, fields: fields)
      end
    end

    def parse_fields(fields_str)
      fields = {}
      # Match: fieldName: multiplicity Type
      field_pattern = /(\w+)\s*:\s*(one|lone|set|seq)?\s*(\w+)/

      fields_str.scan(field_pattern) do |match|
        field_name = match[0]
        multiplicity = match[1] || 'one'
        type = match[2]
        fields[field_name] = {
          type: type,
          multiplicity: multiplicity
        }
      end

      fields
    end

    def parse_predicates(source)
      # Match: pred Name[params] { body }
      pred_pattern = /pred\s+(\w+)\s*\[([^\]]*)\]\s*\{([^}]*)\}/m

      source.scan(pred_pattern) do |match|
        name = match[0]
        params_str = match[1]
        body = match[2].strip
        params = parse_params(params_str)
        @predicates << Predicate.new(name, params: params, body: body)
      end
    end

    def parse_params(params_str)
      params = []
      # Match: name: Type or name, name2: Type
      param_pattern = /(\w+(?:\s*,\s*\w+)*)\s*:\s*(\w+)/

      params_str.scan(param_pattern) do |match|
        names = match[0].split(',').map(&:strip)
        type = match[1]
        names.each do |name|
          params << { name: name, type: type }
        end
      end

      params
    end

    def parse_assertions(source)
      # Match: assert Name { body }
      assert_pattern = /assert\s+(\w+)\s*\{([^}]*)\}/m

      source.scan(assert_pattern) do |match|
        name = match[0]
        body = match[1].strip
        @assertions << Assertion.new(name, body: body)
      end
    end

    def parse_facts(source)
      # Match: fact Name { body } or fact { body }
      fact_pattern = /fact\s*(\w*)\s*\{([^}]*)\}/m

      source.scan(fact_pattern) do |match|
        name = match[0].empty? ? nil : match[0]
        body = match[1].strip
        @facts << { name: name, body: body }
      end
    end
  end
end

# Test the parser
if __FILE__ == $PROGRAM_NAME
  source = File.read(ARGV[0] || 'sort.als')
  parser = AlloyParser::Parser.new
  result = parser.parse(source)

  puts "=== Parsed Alloy Specification ==="
  puts result.to_json
end
