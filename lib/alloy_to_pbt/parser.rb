# frozen_string_literal: true

module AlloyToPbt
  # Data classes for Alloy AST
  Field = Data.define(:name, :type, :multiplicity) do
    def initialize(name:, type:, multiplicity: "one") = super
  end

  Signature = Data.define(:name, :fields, :extends) do
    def initialize(name:, fields: [], extends: nil) = super
  end

  Predicate = Data.define(:name, :params, :body) do
    def initialize(name:, params: [], body: "") = super
  end

  Assertion = Data.define(:name, :body) do
    def initialize(name:, body: "") = super
  end

  Fact = Data.define(:name, :body) do
    def initialize(name: nil, body: "") = super
  end

  Spec = Data.define(:module_name, :signatures, :predicates, :assertions, :facts) do
    def initialize(module_name: nil, signatures: [], predicates: [], assertions: [], facts: []) = super
  end

  # Parser for Alloy specifications
  class Parser
    SIG_PATTERN = /sig\s+(\w+)(?:\s+extends\s+(\w+))?\s*\{([^}]*)\}/m
    FIELD_PATTERN = /(\w+)\s*:\s*(one|lone|set|seq)?\s*(\w+)/
    PRED_PATTERN = /pred\s+(\w+)\s*\[([^\]]*)\]\s*\{([^}]*)\}/m
    PARAM_PATTERN = /([\w,\s]+)\s*:\s*(\w+)/
    ASSERT_PATTERN = /assert\s+(\w+)\s*\{([^}]*)\}/m
    FACT_PATTERN = /fact\s*(\w*)\s*\{([^}]*)\}/m
    MODULE_PATTERN = /module\s+(\w+)/

    attr_reader :spec

    def initialize
      @spec = nil
    end

    def parse(source)
      # Remove comments
      source = remove_comments(source)

      module_name = parse_module(source)
      signatures = parse_signatures(source)
      predicates = parse_predicates(source)
      assertions = parse_assertions(source)
      facts = parse_facts(source)

      @spec = Spec.new(
        module_name:,
        signatures:,
        predicates:,
        assertions:,
        facts:
      )
    end

    def to_h
      raise ParseError, "No spec parsed yet" unless @spec

      {
        module: @spec.module_name,
        signatures: @spec.signatures.map do |sig|
          {
            name: sig.name,
            extends: sig.extends,
            fields: sig.fields.map { |f| { name: f.name, type: f.type, multiplicity: f.multiplicity } }
          }
        end,
        predicates: @spec.predicates.map do |pred|
          {
            name: pred.name,
            params: pred.params,
            body: pred.body
          }
        end,
        assertions: @spec.assertions.map do |a|
          { name: a.name, body: a.body }
        end,
        facts: @spec.facts.map do |f|
          { name: f.name, body: f.body }
        end
      }
    end

    def to_json
      require "json"
      JSON.pretty_generate(to_h)
    end

    private

    def remove_comments(source)
      source
        .gsub(/--.*$/, "")      # -- comments
        .gsub(%r{//.*$}, "")    # // comments
        .gsub(%r{/\*.*?\*/}m, "") # /* */ comments
    end

    def parse_module(source)
      match = source.match(MODULE_PATTERN)
      match&.[](1)
    end

    def parse_signatures(source)
      source.scan(SIG_PATTERN).map do |name, extends, fields_str|
        fields = parse_fields(fields_str)
        Signature.new(name:, fields:, extends:)
      end
    end

    def parse_fields(fields_str)
      fields_str.scan(FIELD_PATTERN).map do |name, multiplicity, type|
        Field.new(name:, type:, multiplicity: multiplicity || "one")
      end
    end

    def parse_predicates(source)
      source.scan(PRED_PATTERN).map do |name, params_str, body|
        params = parse_params(params_str)
        Predicate.new(name:, params:, body: body.strip)
      end
    end

    def parse_params(params_str)
      params = []
      params_str.scan(PARAM_PATTERN) do |names_str, type|
        names_str.split(",").map(&:strip).each do |name|
          params << { name:, type: } unless name.empty?
        end
      end
      params
    end

    def parse_assertions(source)
      source.scan(ASSERT_PATTERN).map do |name, body|
        Assertion.new(name:, body: body.strip)
      end
    end

    def parse_facts(source)
      source.scan(FACT_PATTERN).map do |name, body|
        fact_name = name.empty? ? nil : name
        Fact.new(name: fact_name, body: body.strip)
      end
    end
  end
end
