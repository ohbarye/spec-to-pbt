# frozen_string_literal: true

# rbs_inline: enabled

module SpecToPbt
  class RelatedHintAnalyzer
    # @rbs spec: Core::SpecDocument
    # @rbs core_analysis_resolver: ^(Core::Entity predicate) -> StatefulPredicateAnalysis
    # @rbs normalized_body_resolver: ^(Core::Entity predicate) -> String
    # @rbs normalize_text_resolver: ^(String value) -> String
    # @rbs return: void
    def initialize(spec, core_analysis_resolver:, normalized_body_resolver:, normalize_text_resolver:)
      @spec = spec
      @core_analysis_resolver = core_analysis_resolver
      @normalized_body_resolver = normalized_body_resolver
      @normalize_text_resolver = normalize_text_resolver
    end

    # @rbs predicate: Core::Entity
    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: Hash[Symbol, Array[String] | Array[Symbol]]
    def enrich(predicate:, analysis:)
      related_predicates = related_predicate_names_for(predicate, analysis)
      related_assertions = related_assertion_names_for(predicate, analysis)
      related_facts = related_fact_names_for(predicate, analysis)
      related_pattern_hints = related_pattern_hints_for(related_predicates, related_assertions, related_facts)
      derived_verify_hints = derived_verify_hints_for(
        analysis: analysis,
        related_predicates: related_predicates,
        related_assertions: related_assertions,
        related_facts: related_facts,
        related_pattern_hints: related_pattern_hints
      )

      {
        related_predicate_names: related_predicates,
        related_assertion_names: related_assertions,
        related_fact_names: related_facts,
        related_pattern_hints: related_pattern_hints,
        derived_verify_hints: derived_verify_hints
      }
    end

    private

    # @rbs predicate: Core::Entity
    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: Array[String]
    def related_predicate_names_for(predicate, analysis)
      @spec.properties.filter_map do |other|
        next if other.name == predicate.name
        next if command_analysis_like?(core_analysis_for(other)) && !property_like_name?(other.name)

        other_analysis = core_analysis_for(other)
        next unless related_analysis?(other_analysis, analysis.state_type, analysis.state_field)

        other.name
      end
    end

    # @rbs predicate: Core::Entity
    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: Array[String]
    def related_assertion_names_for(predicate, analysis)
      @spec.assertions.filter_map do |assertion|
        next unless related_text?(assertion, predicate.name, analysis.state_type, analysis.state_field)

        assertion.name
      end
    end

    # @rbs predicate: Core::Entity
    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: Array[String]
    def related_fact_names_for(predicate, analysis)
      @spec.facts.filter_map do |fact|
        next unless related_text?(fact, predicate.name, analysis.state_type, analysis.state_field)

        fact.name
      end
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs related_predicates: Array[String]
    # @rbs related_assertions: Array[String]
    # @rbs related_facts: Array[String]
    # @rbs related_pattern_hints: Array[Symbol]
    # @rbs return: Array[Symbol]
    def derived_verify_hints_for(analysis:, related_predicates:, related_assertions:, related_facts:, related_pattern_hints:)
      hints = [] #: Array[Symbol]
      related_texts = [] #: Array[String]

      related_predicates.each do |name|
        predicate = @spec.properties.find { |item| item.name == name }
        related_texts << normalized_body_for(predicate) if predicate
      end
      related_assertions.each do |name|
        assertion = @spec.assertions.find { |item| item.name == name }
        related_texts << normalize_text(assertion.normalized_text) if assertion
      end
      related_facts.each do |name|
        fact = @spec.facts.find { |item| item.name == name }
        related_texts << normalize_text(fact.normalized_text) if fact
      end

      hints << :respect_non_empty_guard if analysis.guard_kind == :non_empty || related_texts.any? { |text| text.match?(/not ?IsEmpty|>0|>=1/i) }
      hints << :respect_capacity_guard if analysis.guard_kind == :below_capacity || related_texts.any? { |text| text.match?(/IsFull|capacity|limit|max(?:imum)?/i) }
      hints << :check_empty_semantics if related_pattern_hints.include?(:empty)
      hints << :check_ordering_semantics if related_pattern_hints.include?(:ordering)
      hints << :check_roundtrip_pairing if related_pattern_hints.include?(:roundtrip)
      hints << :check_size_semantics if related_pattern_hints.include?(:size)
      hints << :check_membership_semantics if related_pattern_hints.include?(:membership)
      hints << :check_non_negative_scalar_state if related_texts.any? { |text| text.match?(/NonNegative|>=0/) }
      if ["seq", "set"].include?(analysis.state_field_multiplicity) &&
          analysis.state_field_updates.any? { |update| [:increment, :decrement].include?(update[:update_shape]) && update[:rhs_source_kind] == :arg }
        hints << :check_projection_semantics
      end
      predicate = @spec.properties.find { |item| item.name == analysis.predicate_name }
      predicate_text = predicate ? normalized_body_for(predicate) : ""
      if analysis.guard_kind != :none && predicate_text.include?("implies")
        hints << :check_guard_failure_semantics
      end

      hints.uniq
    end

    # @rbs related_predicates: Array[String]
    # @rbs related_assertions: Array[String]
    # @rbs related_facts: Array[String]
    # @rbs return: Array[Symbol]
    def related_pattern_hints_for(related_predicates, related_assertions, related_facts)
      predicate_texts = related_predicates.filter_map do |name|
        predicate = @spec.properties.find { |item| item.name == name }
        predicate && "#{predicate.name} #{normalized_body_for(predicate)}"
      end
      assertion_texts = related_assertions.filter_map do |name|
        assertion = @spec.assertions.find { |item| item.name == name }
        assertion && "#{assertion.name} #{normalize_text(assertion.normalized_text)}"
      end
      fact_texts = related_facts.filter_map do |name|
        fact = @spec.facts.find { |item| item.name == name }
        fact && "#{fact.name} #{normalize_text(fact.normalized_text)}"
      end

      (predicate_texts + assertion_texts + fact_texts)
        .flat_map { |text| PropertyPattern.detect("", text) }
        .uniq
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs state_type: String?
    # @rbs state_field: String?
    # @rbs return: bool
    def related_analysis?(analysis, state_type, state_field)
      return true if !state_type.nil? && analysis.state_type == state_type
      return true if !state_field.nil? && analysis.state_field == state_field

      false
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: bool
    def command_analysis_like?(analysis)
      return true if [:append, :pop, :dequeue, :size_no_change].include?(analysis.transition_kind)
      return true if [:append_like, :remove_first, :remove_last, :preserve_size].include?(analysis.state_update_shape)

      false
    end

    # @rbs entry: Core::Entity
    # @rbs predicate_name: String
    # @rbs state_type: String?
    # @rbs state_field: String?
    # @rbs return: bool
    def related_text?(entry, predicate_name, state_type, state_field)
      body = normalize_text(entry.normalized_text)
      return true if body.match?(/\b#{Regexp.escape(predicate_name)}\[/)

      type_match = !state_type.nil? && body.match?(/\b#{Regexp.escape(state_type)}\b/)
      field_match = !state_field.nil? && body.match?(/\b#{Regexp.escape(state_field)}\b/)
      pattern_match = PropertyPattern.detect("", body).any?

      (type_match || field_match) && pattern_match
    end

    # @rbs name: String
    # @rbs return: bool
    def property_like_name?(name)
      name.match?(/(?:Identity|Roundtrip|Invariant|Sorted|LIFO|FIFO|IsEmpty|Empty|IsFull|Full)\z/i)
    end

    # @rbs predicate: Core::Entity
    # @rbs return: StatefulPredicateAnalysis
    def core_analysis_for(predicate)
      @core_analysis_resolver.call(predicate)
    end

    # @rbs predicate: Core::Entity
    # @rbs return: String
    def normalized_body_for(predicate)
      @normalized_body_resolver.call(predicate)
    end

    # @rbs value: String
    # @rbs return: String
    def normalize_text(value)
      @normalize_text_resolver.call(value)
    end
  end
end
