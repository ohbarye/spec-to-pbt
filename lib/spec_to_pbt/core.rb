# frozen_string_literal: true

# rbs_inline: enabled

module SpecToPbt
  module Core
    Field = Data.define(:name, :type, :multiplicity, :metadata) do
      # @rbs name: String
      # @rbs type: String
      # @rbs multiplicity: String
      # @rbs metadata: Hash[Symbol, untyped]
      # @rbs return: void
      def initialize(name:, type:, multiplicity: "one", metadata: {}) = super
    end

    Parameter = Data.define(:name, :type, :role, :metadata) do
      # @rbs name: String
      # @rbs type: String
      # @rbs role: Symbol
      # @rbs metadata: Hash[Symbol, untyped]
      # @rbs return: void
      def initialize(name:, type:, role: :unknown, metadata: {}) = super
    end

    Entity = Data.define(:name, :kind, :params, :fields, :raw_text, :normalized_text, :metadata) do
      # @rbs name: String
      # @rbs kind: Symbol
      # @rbs params: Array[Parameter]
      # @rbs fields: Array[Field]
      # @rbs raw_text: String
      # @rbs normalized_text: String
      # @rbs metadata: Hash[Symbol, untyped]
      # @rbs return: void
      def initialize(name:, kind:, params: [], fields: [], raw_text: "", normalized_text: raw_text, metadata: {}) = super
    end

    SpecDocument = Data.define(:name, :entities, :types, :properties, :assertions, :facts, :source_format, :metadata) do
      # @rbs name: String?
      # @rbs entities: Array[Entity]
      # @rbs types: Array[Entity]
      # @rbs properties: Array[Entity]
      # @rbs assertions: Array[Entity]
      # @rbs facts: Array[Entity]
      # @rbs source_format: Symbol
      # @rbs metadata: Hash[Symbol, untyped]
      # @rbs return: void
      def initialize(name: nil, entities: [], types: [], properties: [], assertions: [], facts: [], source_format: :unknown, metadata: {}) = super
    end

    module Coercion
      module_function

      # @rbs spec: untyped
      # @rbs return: SpecDocument
      def call(spec)
        return spec if spec.is_a?(SpecDocument)

        if defined?(SpecToPbt::Spec) && spec.is_a?(SpecToPbt::Spec)
          return SpecToPbt::Frontends::Alloy::Adapter.new.adapt(spec)
        end

        raise SpecToPbt::Error, "Unsupported spec document: #{spec.class}"
      end
    end
  end
end
