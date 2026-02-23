# frozen_string_literal: true

# rbs_inline: enabled

module SpecToPbt
  # Represents an Alloy signature field
  # @rbs name: String
  # @rbs type: String
  # @rbs multiplicity: String
  Field = Data.define(:name, :type, :multiplicity) do
    # @rbs name: String
    # @rbs type: String
    # @rbs multiplicity: String
    # @rbs return: void
    def initialize(name:, type:, multiplicity: "one") = super
  end

  # Represents an Alloy signature
  # @rbs name: String
  # @rbs fields: Array[Field]
  # @rbs extends: String?
  Signature = Data.define(:name, :fields, :extends) do
    # @rbs name: String
    # @rbs fields: Array[Field]
    # @rbs extends: String?
    # @rbs return: void
    def initialize(name:, fields: [], extends: nil) = super
  end

  # Represents an Alloy predicate
  # @rbs name: String
  # @rbs params: Array[Hash[Symbol, String]]
  # @rbs body: String
  Predicate = Data.define(:name, :params, :body) do
    # @rbs name: String
    # @rbs params: Array[Hash[Symbol, String]]
    # @rbs body: String
    # @rbs return: void
    def initialize(name:, params: [], body: "") = super
  end

  # Represents an Alloy assertion
  # @rbs name: String
  # @rbs body: String
  Assertion = Data.define(:name, :body) do
    # @rbs name: String
    # @rbs body: String
    # @rbs return: void
    def initialize(name:, body: "") = super
  end

  # Represents an Alloy fact
  # @rbs name: String?
  # @rbs body: String
  Fact = Data.define(:name, :body) do
    # @rbs name: String?
    # @rbs body: String
    # @rbs return: void
    def initialize(name: nil, body: "") = super
  end

  # Represents an Alloy specification
  # @rbs module_name: String?
  # @rbs signatures: Array[Signature]
  # @rbs predicates: Array[Predicate]
  # @rbs assertions: Array[Assertion]
  # @rbs facts: Array[Fact]
  Spec = Data.define(:module_name, :signatures, :predicates, :assertions, :facts) do
    # @rbs module_name: String?
    # @rbs signatures: Array[Signature]
    # @rbs predicates: Array[Predicate]
    # @rbs assertions: Array[Assertion]
    # @rbs facts: Array[Fact]
    # @rbs return: void
    def initialize(module_name: nil, signatures: [], predicates: [], assertions: [], facts: []) = super
  end

  # Parser for Alloy specifications
  class Parser
    SIG_PATTERN = /sig\s+(\w+)(?:\s+extends\s+(\w+))?\s*\{([^}]*)\}/m #: Regexp
    FIELD_PATTERN = /(\w+)\s*:\s*(one|lone|set|seq)?\s*(\w+)/ #: Regexp
    PRED_PATTERN = /pred\s+(\w+)\s*\[([^\]]*)\]\s*\{([^}]*)\}/m #: Regexp
    PARAM_PATTERN = /([\w,\s]+)\s*:\s*(\w+)/ #: Regexp
    ASSERT_PATTERN = /assert\s+(\w+)\s*\{([^}]*)\}/m #: Regexp
    FACT_PATTERN = /fact\s*(\w*)\s*\{([^}]*)\}/m #: Regexp
    MODULE_PATTERN = /module\s+(\w+)/ #: Regexp

    attr_reader :spec #: Spec?

    # @rbs return: void
    def initialize
      @spec = nil #: Spec?
    end

    # Parse an Alloy specification source
    # @rbs source: String
    # @rbs return: Spec
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

    # Convert spec to hash representation
    # @rbs return: Hash[Symbol, untyped]
    def to_h
      spec = @spec
      raise ParseError, "No spec parsed yet" unless spec

      {
        module: spec.module_name,
        signatures: spec.signatures.map do |sig|
          {
            name: sig.name,
            extends: sig.extends,
            fields: sig.fields.map { |f| { name: f.name, type: f.type, multiplicity: f.multiplicity } }
          }
        end,
        predicates: spec.predicates.map do |pred|
          {
            name: pred.name,
            params: pred.params,
            body: pred.body
          }
        end,
        assertions: spec.assertions.map do |a|
          { name: a.name, body: a.body }
        end,
        facts: spec.facts.map do |f|
          { name: f.name, body: f.body }
        end
      }
    end

    # Convert spec to JSON string
    # @rbs return: String
    def to_json
      require "json"
      JSON.pretty_generate(to_h)
    end

    private

    # Remove comments from source
    # @rbs source: String
    # @rbs return: String
    def remove_comments(source)
      source
        .gsub(/--.*$/, "")      # -- comments
        .gsub(%r{//.*$}, "")    # // comments
        .gsub(%r{/\*.*?\*/}m, "") # /* */ comments
    end

    # Parse module name
    # @rbs source: String
    # @rbs return: String?
    def parse_module(source)
      match = source.match(MODULE_PATTERN)
      match&.[](1)
    end

    # Parse signatures
    # @rbs source: String
    # @rbs return: Array[Signature]
    def parse_signatures(source)
      source.scan(SIG_PATTERN).map do |name, extends, fields_str|
        fields = parse_fields(fields_str.to_s)
        Signature.new(name: name.to_s, fields:, extends:)
      end
    end

    # Parse fields from field string
    # @rbs fields_str: String
    # @rbs return: Array[Field]
    def parse_fields(fields_str)
      fields_str.scan(FIELD_PATTERN).map do |name, multiplicity, type|
        Field.new(name: name.to_s, type: type.to_s, multiplicity: multiplicity || "one")
      end
    end

    # Parse predicates
    # @rbs source: String
    # @rbs return: Array[Predicate]
    def parse_predicates(source)
      source.scan(PRED_PATTERN).map do |name, params_str, body|
        params = parse_params(params_str.to_s)
        Predicate.new(name: name.to_s, params:, body: body.to_s.strip)
      end
    end

    # Parse predicate parameters
    # @rbs params_str: String
    # @rbs return: Array[Hash[Symbol, String]]
    def parse_params(params_str)
      params = [] #: Array[Hash[Symbol, String]]
      params_str.scan(PARAM_PATTERN) do |names_str, type|
        names_str.to_s.split(",").map(&:strip).each do |name|
          params << { name:, type: type.to_s } unless name.empty?
        end
      end
      params
    end

    # Parse assertions
    # @rbs source: String
    # @rbs return: Array[Assertion]
    def parse_assertions(source)
      source.scan(ASSERT_PATTERN).map do |name, body|
        Assertion.new(name: name.to_s, body: body.to_s.strip)
      end
    end

    # Parse facts
    # @rbs source: String
    # @rbs return: Array[Fact]
    def parse_facts(source)
      source.scan(FACT_PATTERN).map do |name, body|
        name_str = name.to_s
        fact_name = name_str.empty? ? nil : name_str
        Fact.new(name: fact_name, body: body.to_s.strip)
      end
    end
  end
end
