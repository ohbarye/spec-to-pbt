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
  # @rbs normalized_body: String
  Predicate = Data.define(:name, :params, :body, :normalized_body) do
    # @rbs name: String
    # @rbs params: Array[Hash[Symbol, String]]
    # @rbs body: String
    # @rbs normalized_body: String
    # @rbs return: void
    def initialize(name:, params: [], body: "", normalized_body: body) = super
  end

  # Represents an Alloy assertion
  # @rbs name: String
  # @rbs body: String
  # @rbs normalized_body: String
  Assertion = Data.define(:name, :body, :normalized_body) do
    # @rbs name: String
    # @rbs body: String
    # @rbs normalized_body: String
    # @rbs return: void
    def initialize(name:, body: "", normalized_body: body) = super
  end

  # Represents an Alloy fact
  # @rbs name: String?
  # @rbs body: String
  # @rbs normalized_body: String
  Fact = Data.define(:name, :body, :normalized_body) do
    # @rbs name: String?
    # @rbs body: String
    # @rbs normalized_body: String
    # @rbs return: void
    def initialize(name: nil, body: "", normalized_body: body) = super
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
    attr_reader :spec #: Spec?

    # @rbs return: void
    def initialize
      @spec = nil #: Spec?
      @frontend_parser = Frontends::Alloy::Parser.new #: Frontends::Alloy::Parser
    end

    # Parse an Alloy specification source
    # @rbs source: String
    # @rbs return: Spec
    def parse(source)
      @spec = @frontend_parser.parse(source)
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
            body: pred.body,
            normalized_body: pred.normalized_body
          }
        end,
        assertions: spec.assertions.map do |a|
          { name: a.name, body: a.body, normalized_body: a.normalized_body }
        end,
        facts: spec.facts.map do |f|
          { name: f.name, body: f.body, normalized_body: f.normalized_body }
        end
      }
    end

    # Convert spec to JSON string
    # @rbs return: String
    def to_json
      require "json"
      JSON.pretty_generate(to_h)
    end
  end
end
