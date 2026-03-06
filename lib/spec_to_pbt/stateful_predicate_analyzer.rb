# frozen_string_literal: true

# rbs_inline: enabled

module SpecToPbt
  StatefulPredicateAnalysis = Data.define(
    :predicate_name,
    :state_param_names,
    :state_type,
    :argument_params,
    :state_field,
    :state_field_multiplicity,
    :size_delta,
    :requires_non_empty_state,
    :transition_kind,
    :result_position,
    :scalar_update_kind,
    :command_confidence,
    :guard_kind,
    :rhs_source_kind,
    :state_update_shape,
    :related_predicate_names,
    :related_assertion_names,
    :related_fact_names,
    :related_pattern_hints,
    :derived_verify_hints
  ) do
    # @rbs predicate_name: String
    # @rbs state_param_names: Array[String]
    # @rbs state_type: String?
    # @rbs argument_params: Array[Hash[Symbol, String]]
    # @rbs state_field: String?
    # @rbs state_field_multiplicity: String?
    # @rbs size_delta: Integer?
    # @rbs requires_non_empty_state: bool
    # @rbs transition_kind: Symbol?
    # @rbs result_position: Symbol?
    # @rbs scalar_update_kind: Symbol?
    # @rbs command_confidence: Symbol
    # @rbs guard_kind: Symbol
    # @rbs rhs_source_kind: Symbol
    # @rbs state_update_shape: Symbol
    # @rbs related_predicate_names: Array[String]
    # @rbs related_assertion_names: Array[String]
    # @rbs related_fact_names: Array[String]
    # @rbs related_pattern_hints: Array[Symbol]
    # @rbs derived_verify_hints: Array[Symbol]
    # @rbs return: void
    def initialize(predicate_name:, state_param_names: [], state_type: nil, argument_params: [], state_field: nil, state_field_multiplicity: nil, size_delta: nil, requires_non_empty_state: false, transition_kind: nil, result_position: nil, scalar_update_kind: nil, command_confidence: :low, guard_kind: :none, rhs_source_kind: :unknown, state_update_shape: :unknown, related_predicate_names: [], related_assertion_names: [], related_fact_names: [], related_pattern_hints: [], derived_verify_hints: []) = super
  end

  # Extracts minimal stateful command hints from a predicate body.
  class StatefulPredicateAnalyzer
    # @rbs spec: untyped
    # @rbs return: void
    def initialize(spec)
      @spec = Core::Coercion.call(spec) #: Core::SpecDocument
      @signature_names = @spec.types.map(&:name) #: Array[String]
      @module_state_name = @spec.name&.then { |name| camelize(name) } #: String?
      @analyses = {} #: Hash[String, StatefulPredicateAnalysis]
    end

    # @rbs predicate: Core::Entity
    # @rbs return: StatefulPredicateAnalysis
    def analyze(predicate)
      predicate = coerce_property_entity(predicate)
      return @analyses[predicate.name] if @analyses.key?(predicate.name)

      state_param_names, state_type = infer_state_params(predicate)
      argument_params = predicate.params.reject do |param|
        @signature_names.include?(param.name) || state_param_names.include?(param.name)
      end
      if state_type
        argument_params = argument_params.reject { |param| param.type == state_type && state_param_names.include?(param.name) }
      end

      body = normalized_body_for(predicate)
      state_field = infer_state_field(body, state_param_names)
      state_field_multiplicity = infer_state_field_multiplicity(state_type, state_field)
      size_delta = infer_size_delta(body)
      guard_kind = infer_guard_kind(body)
      requires_non_empty_state = guard_kind != :none
      transition_kind = infer_transition_kind(predicate.name, body, size_delta, requires_non_empty_state)
      scalar_update_kind = infer_scalar_update_kind(body, state_field, state_field_multiplicity)
      rhs_source_kind = infer_rhs_source_kind(body, predicate, state_field)
      state_update_shape = infer_state_update_shape(
        state_field_multiplicity: state_field_multiplicity,
        size_delta: size_delta,
        transition_kind: transition_kind,
        scalar_update_kind: scalar_update_kind,
        rhs_source_kind: rhs_source_kind,
        body: body,
        state_field: state_field
      )

      analysis = StatefulPredicateAnalysis.new(
        predicate_name: predicate.name,
        state_param_names: state_param_names,
        state_type: state_type,
        argument_params: argument_params,
        state_field: state_field,
        state_field_multiplicity: state_field_multiplicity,
        size_delta: size_delta,
        requires_non_empty_state: requires_non_empty_state,
        transition_kind: transition_kind,
        result_position: infer_result_position(predicate.name, transition_kind),
        scalar_update_kind: scalar_update_kind,
        command_confidence: infer_command_confidence(predicate.name, transition_kind, size_delta, requires_non_empty_state, scalar_update_kind, state_update_shape),
        guard_kind: guard_kind,
        rhs_source_kind: rhs_source_kind,
        state_update_shape: state_update_shape
      )
      @analyses[predicate.name] = analysis

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

      @analyses[predicate.name] = analysis.with(
        related_predicate_names: related_predicates,
        related_assertion_names: related_assertions,
        related_fact_names: related_facts,
        related_pattern_hints: related_pattern_hints,
        derived_verify_hints: derived_verify_hints
      )
    end

    private

    # @rbs predicate: Core::Entity
    # @rbs return: Array[Array[String] | String?]
    def infer_state_params(predicate)
      params_by_name = predicate.params.to_h { |param| [param.name, param] }

      predicate.params.each do |param|
        next unless param.name.end_with?("'")

        base_name = param.name.delete_suffix("'")
        base = params_by_name[base_name]
        next unless base
        next unless base.type == param.type

        return [[base_name, param.name], param.type]
      end

      return [[], nil] unless @module_state_name

      state_params = predicate.params.select { |param| param.type == @module_state_name }.map(&:name)
      [state_params, (state_params.empty? ? nil : @module_state_name)]
    end

    # @rbs predicate: Core::Entity
    # @rbs return: String
    def normalized_body_for(predicate)
      if !predicate.normalized_text.to_s.empty?
        predicate.normalized_text.to_s
      else
        normalize_text(predicate.raw_text)
      end
    end

    # @rbs body: String
    # @rbs return: Integer?
    def infer_size_delta(body)
      return 1 if body.match?(/#\w+'?\.\w+=(?:add\[|#\w+\.?\w*\+1)/)
      return -1 if body.match?(/#\w+'?\.\w+=(?:sub\[|#\w+\.?\w*-1)/)
      return 0 if body.match?(/#\w+'?\.\w+=#\w+\.?\w*/)

      nil
    end

    # @rbs body: String
    # @rbs return: Symbol
    def infer_guard_kind(body)
      return :non_empty if body.match?(/#\w+\.?\w*\s*(?:>\s*0|>=\s*1)/)

      :none
    end

    # @rbs body: String
    # @rbs state_param_names: Array[String]
    # @rbs return: String?
    def infer_state_field(body, state_param_names)
      state_param_names.each do |param_name|
        match = body.match(/##{Regexp.escape(param_name)}\.(\w+)/)
        return match[1] if match
      end

      match = body.match(/#\w+'?\.(\w+)/)
      match && match[1]
    end

    # @rbs state_type: String?
    # @rbs state_field: String?
    # @rbs return: String?
    def infer_state_field_multiplicity(state_type, state_field)
      return nil unless state_type && state_field

      type_entity = @spec.types.find { |item| item.name == state_type }
      return nil unless type_entity

      field = type_entity.fields.find { |item| item.name == state_field }
      field&.multiplicity
    end

    # @rbs predicate_name: String
    # @rbs body: String
    # @rbs size_delta: Integer?
    # @rbs requires_non_empty_state: bool
    # @rbs return: Symbol?
    def infer_transition_kind(predicate_name, body, size_delta, requires_non_empty_state)
      return :append if size_delta == 1
      if size_delta == -1
        return :dequeue if dequeue_like_text?(predicate_name, body)
        return :pop if pop_like_text?(predicate_name, body)
        return :pop if requires_non_empty_state
      end
      return :size_no_change if size_delta == 0

      nil
    end

    # @rbs predicate_name: String
    # @rbs transition_kind: Symbol?
    # @rbs return: Symbol?
    def infer_result_position(predicate_name, transition_kind)
      return :first if transition_kind == :dequeue
      return :last if transition_kind == :pop
      return :first if predicate_name.match?(/\A(?:Shift|Dequeue)/i)
      return :last if predicate_name.match?(/\A(?:Pop|Remove|Delete|Get)/i)

      nil
    end

    # @rbs body: String
    # @rbs state_field: String?
    # @rbs state_field_multiplicity: String?
    # @rbs return: Symbol?
    def infer_scalar_update_kind(body, state_field, state_field_multiplicity)
      return nil if state_field.nil?
      return nil if ["seq", "set"].include?(state_field_multiplicity)

      return :increment_like if body.match?(/#\w+'?\.#{Regexp.escape(state_field)}=(?:add\[|#\w+\.?#{Regexp.escape(state_field)}\+1)/)
      return :decrement_like if body.match?(/#\w+'?\.#{Regexp.escape(state_field)}=(?:sub\[|#\w+\.?#{Regexp.escape(state_field)}-1)/)
      return :replace_like if body.match?(/#\w+'?\.#{Regexp.escape(state_field)}=#?\w+/)

      nil
    end

    # @rbs body: String
    # @rbs predicate: Core::Entity
    # @rbs state_field: String?
    # @rbs return: Symbol
    def infer_rhs_source_kind(body, predicate, state_field)
      return :unknown if state_field.nil?

      predicate.params.each do |param|
        next if param.name.end_with?("'")
        next if body.match?(/#\w+'?\.#{Regexp.escape(state_field)}=#?\w+\.#{Regexp.escape(state_field)}/)

        return :arg if body.match?(/#\w+'?\.#{Regexp.escape(state_field)}=#?#{Regexp.escape(param.name)}\b/)
      end

      return :state_field if body.match?(/#\w+'?\.#{Regexp.escape(state_field)}=#\w+\.#{Regexp.escape(state_field)}/)

      :unknown
    end

    # @rbs state_field_multiplicity: String?
    # @rbs size_delta: Integer?
    # @rbs transition_kind: Symbol?
    # @rbs scalar_update_kind: Symbol?
    # @rbs rhs_source_kind: Symbol
    # @rbs body: String
    # @rbs state_field: String?
    # @rbs return: Symbol
    def infer_state_update_shape(state_field_multiplicity:, size_delta:, transition_kind:, scalar_update_kind:, rhs_source_kind:, body:, state_field:)
      if ["seq", "set"].include?(state_field_multiplicity)
        return :append_like if size_delta == 1
        return :remove_first if transition_kind == :dequeue
        return :remove_last if transition_kind == :pop
        return :preserve_size if size_delta == 0
        return :unknown
      end

      return :preserve_value if state_field && body.match?(/\A#\w+'?\.#{Regexp.escape(state_field)}=#\w+\.#{Regexp.escape(state_field)}\z/)
      return :increment if scalar_update_kind == :increment_like
      return :decrement if scalar_update_kind == :decrement_like
      return :replace_with_arg if scalar_update_kind == :replace_like && rhs_source_kind == :arg
      return :replace_value if scalar_update_kind == :replace_like

      :unknown
    end

    # @rbs predicate_name: String
    # @rbs transition_kind: Symbol?
    # @rbs size_delta: Integer?
    # @rbs requires_non_empty_state: bool
    # @rbs scalar_update_kind: Symbol?
    # @rbs state_update_shape: Symbol
    # @rbs return: Symbol
    def infer_command_confidence(predicate_name, transition_kind, size_delta, requires_non_empty_state, scalar_update_kind, state_update_shape)
      return :high if predicate_name.match?(/\A(?:Push|Pop|Enqueue|Dequeue|Add|Remove|Insert|Delete|Put|Get)/)
      return :high if [:append, :pop, :dequeue].include?(transition_kind)
      return :high if [:append_like, :remove_first, :remove_last].include?(state_update_shape)
      return :medium if transition_kind == :size_no_change
      return :medium if [:increment, :decrement, :replace_with_arg, :replace_value, :preserve_value].include?(state_update_shape)
      return :medium if !scalar_update_kind.nil?
      return :medium if !size_delta.nil? || requires_non_empty_state

      :low
    end

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

    # @rbs predicate: Core::Entity
    # @rbs return: StatefulPredicateAnalysis
    def core_analysis_for(predicate)
      predicate = coerce_property_entity(predicate)
      existing = @analyses[predicate.name]
      return existing if existing

      analyze(predicate).with(
        related_predicate_names: [],
        related_assertion_names: [],
        related_fact_names: [],
        related_pattern_hints: [],
        derived_verify_hints: []
      )
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
      hints << :check_empty_semantics if related_pattern_hints.include?(:empty)
      hints << :check_ordering_semantics if related_pattern_hints.include?(:ordering)
      hints << :check_roundtrip_pairing if related_pattern_hints.include?(:roundtrip)
      hints << :check_size_semantics if related_pattern_hints.include?(:size)

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

    # @rbs predicate: Core::Entity
    # @rbs return: bool
    def looks_like_command?(predicate)
      return false if property_like_name?(predicate.name)

      body = normalized_body_for(predicate)
      PropertyPattern.detect(predicate.name, body).empty? &&
        (body.include?("'") || predicate.name.match?(/\A(?:Push|Pop|Enqueue|Dequeue|Add|Remove|Insert|Delete|Put|Get)/))
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

    # @rbs predicate_name: String
    # @rbs body: String
    # @rbs return: bool
    def dequeue_like_text?(predicate_name, body)
      text = "#{predicate_name} #{body}"
      text.match?(/(?:dequeue|shift|front|head|first)/i)
    end

    # @rbs predicate_name: String
    # @rbs body: String
    # @rbs return: bool
    def pop_like_text?(predicate_name, body)
      text = "#{predicate_name} #{body}"
      text.match?(/(?:pop|drop.*last|remove.*last|tail|back|end|last)/i)
    end

    # @rbs name: String
    # @rbs return: bool
    def property_like_name?(name)
      name.match?(/(?:Identity|Roundtrip|Invariant|Sorted|LIFO|FIFO|IsEmpty|Empty)\z/i)
    end

    # @rbs value: String
    # @rbs return: String
    def camelize(value)
      value.to_s.split(/[^a-zA-Z0-9]+/).reject(&:empty?).map { |part| part[0].upcase + part[1..] }.join
    end

    # @rbs value: String
    # @rbs return: String
    def normalize_text(value)
      value.to_s.gsub(/\s+/, " ").strip
    end

    # @rbs predicate: untyped
    # @rbs return: Core::Entity
    def coerce_property_entity(predicate)
      return predicate if predicate.is_a?(Core::Entity)

      Core::Entity.new(
        name: predicate.name,
        kind: :property,
        params: predicate.params.map do |param|
          Core::Parameter.new(name: param[:name], type: param[:type], role: :unknown)
        end,
        raw_text: predicate.body,
        normalized_text: predicate.respond_to?(:normalized_body) ? predicate.normalized_body : normalize_text(predicate.body),
        metadata: {}
      )
    end
  end
end
