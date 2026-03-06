# frozen_string_literal: true

# rbs_inline: enabled

module SpecToPbt
  module Frontends
    module Alloy
      class Parser
        SIG_PATTERN = /sig\s+(\w+)(?:\s+extends\s+(\w+))?\s*\{([^}]*)\}/m #: Regexp
        FIELD_PATTERN = /(\w+)\s*:\s*(one|lone|set|seq)?\s*(\w+)/ #: Regexp
        PRED_PATTERN = /pred\s+(\w+)\s*\[([^\]]*)\]\s*\{([^}]*)\}/m #: Regexp
        PARAM_PATTERN = /([\w',\s]+)\s*:\s*(\w+)/ #: Regexp
        ASSERT_PATTERN = /assert\s+(\w+)\s*\{([^}]*)\}/m #: Regexp
        FACT_PATTERN = /fact\s*(\w*)\s*\{([^}]*)\}/m #: Regexp
        MODULE_PATTERN = /module\s+(\w+)/ #: Regexp

        attr_reader :spec #: Spec?

        # @rbs return: void
        def initialize
          @spec = nil #: Spec?
        end

        # @rbs source: String
        # @rbs return: Spec
        def parse(source)
          source = remove_comments(source)

          module_name = parse_module(source)
          signatures = parse_signatures(source)
          predicates = parse_predicates(source)
          assertions = parse_assertions(source)
          facts = parse_facts(source)

          @spec = Spec.new(
            module_name: module_name,
            signatures: signatures,
            predicates: predicates,
            assertions: assertions,
            facts: facts
          )
        end

        private

        # @rbs source: String
        # @rbs return: String
        def remove_comments(source)
          source
            .gsub(/--.*$/, "")
            .gsub(%r{//.*$}, "")
            .gsub(%r{/\*.*?\*/}m, "")
        end

        # @rbs source: String
        # @rbs return: String?
        def parse_module(source)
          match = source.match(MODULE_PATTERN)
          match&.[](1)
        end

        # @rbs source: String
        # @rbs return: Array[Signature]
        def parse_signatures(source)
          source.scan(SIG_PATTERN).map do |name, extends, fields_str|
            fields = parse_fields(fields_str.to_s)
            Signature.new(name: name.to_s, fields: fields, extends: extends)
          end
        end

        # @rbs fields_str: String
        # @rbs return: Array[Field]
        def parse_fields(fields_str)
          fields_str.scan(FIELD_PATTERN).map do |name, multiplicity, type|
            Field.new(name: name.to_s, type: type.to_s, multiplicity: multiplicity || "one")
          end
        end

        # @rbs source: String
        # @rbs return: Array[Predicate]
        def parse_predicates(source)
          source.scan(PRED_PATTERN).map do |name, params_str, body|
            params = parse_params(params_str.to_s)
            raw_body = body.to_s.strip
            Predicate.new(name: name.to_s, params: params, body: raw_body, normalized_body: normalize_body(raw_body))
          end
        end

        # @rbs params_str: String
        # @rbs return: Array[Hash[Symbol, String]]
        def parse_params(params_str)
          params = [] #: Array[Hash[Symbol, String]]
          params_str.scan(PARAM_PATTERN) do |names_str, type|
            names_str.to_s.split(",").map(&:strip).each do |name|
              params << { name: name, type: type.to_s } unless name.empty?
            end
          end
          params
        end

        # @rbs source: String
        # @rbs return: Array[Assertion]
        def parse_assertions(source)
          source.scan(ASSERT_PATTERN).map do |name, body|
            raw_body = body.to_s.strip
            Assertion.new(name: name.to_s, body: raw_body, normalized_body: normalize_body(raw_body))
          end
        end

        # @rbs source: String
        # @rbs return: Array[Fact]
        def parse_facts(source)
          source.scan(FACT_PATTERN).map do |name, body|
            raw_body = body.to_s.strip
            name_str = name.to_s
            Fact.new(name: (name_str.empty? ? nil : name_str), body: raw_body, normalized_body: normalize_body(raw_body))
          end
        end

        # @rbs body: String
        # @rbs return: String
        def normalize_body(body)
          body
            .gsub(/\s+/, " ")
            .gsub(/\s*([=+\-#\[\]\{\}\(\),.:|<>])\s*/, '\1')
            .strip
        end
      end
    end
  end
end
