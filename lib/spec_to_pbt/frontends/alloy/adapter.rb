# frozen_string_literal: true

# rbs_inline: enabled

module SpecToPbt
  module Frontends
    module Alloy
      class Adapter
        # @rbs raw_spec: Spec
        # @rbs return: Core::SpecDocument
        def adapt(raw_spec)
          type_entities = raw_spec.signatures.map { |signature| adapt_signature(signature, raw_spec.module_name) }
          property_entities = raw_spec.predicates.map { |predicate| adapt_predicate(predicate) }
          assertion_entities = raw_spec.assertions.map { |assertion| adapt_assertion(assertion) }
          fact_entities = raw_spec.facts.map { |fact| adapt_fact(fact) }

          Core::SpecDocument.new(
            name: raw_spec.module_name,
            entities: type_entities + property_entities + assertion_entities + fact_entities,
            types: type_entities,
            properties: property_entities,
            assertions: assertion_entities,
            facts: fact_entities,
            source_format: :alloy,
            metadata: { raw_spec: raw_spec }
          )
        end

        private

        # @rbs signature: Signature
        # @rbs module_name: String?
        # @rbs return: Core::Entity
        def adapt_signature(signature, module_name)
          Core::Entity.new(
            name: signature.name,
            kind: :type,
            fields: signature.fields.map do |field|
              Core::Field.new(name: field.name, type: field.type, multiplicity: field.multiplicity)
            end,
            metadata: {
              category: signature.name == camelize(module_name) ? :module_state_type : :domain_type,
              extends: signature.extends
            }
          )
        end

        # @rbs predicate: Predicate
        # @rbs return: Core::Entity
        def adapt_predicate(predicate)
          Core::Entity.new(
            name: predicate.name,
            kind: :property,
            params: predicate.params.map { |param| adapt_param(param) },
            raw_text: predicate.body,
            normalized_text: predicate.normalized_body,
            metadata: {}
          )
        end

        # @rbs assertion: Assertion
        # @rbs return: Core::Entity
        def adapt_assertion(assertion)
          Core::Entity.new(
            name: assertion.name,
            kind: :assertion,
            raw_text: assertion.body,
            normalized_text: assertion.normalized_body,
            metadata: {}
          )
        end

        # @rbs fact: Fact
        # @rbs return: Core::Entity
        def adapt_fact(fact)
          Core::Entity.new(
            name: fact.name || "<anonymous fact>",
            kind: :fact,
            raw_text: fact.body,
            normalized_text: fact.normalized_body,
            metadata: { anonymous: fact.name.nil? }
          )
        end

        # @rbs param: Hash[Symbol, String]
        # @rbs return: Core::Parameter
        def adapt_param(param)
          Core::Parameter.new(name: param[:name], type: param[:type], role: :unknown)
        end

        # @rbs value: String?
        # @rbs return: String
        def camelize(value)
          value.to_s.split(/[^a-zA-Z0-9]+/).reject(&:empty?).map { |part| part[0].upcase + part[1..] }.join
        end
      end
    end
  end
end
