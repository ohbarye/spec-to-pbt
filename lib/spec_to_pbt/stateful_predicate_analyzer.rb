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
    :guard,
    :guard_kind,
    :guard_field,
    :guard_constant,
    :rhs_source_kind,
    :rhs_source_field,
    :rhs_constant,
    :state_field_updates,
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
    # @rbs guard: GuardAnalysis
    # @rbs guard_kind: Symbol
    # @rbs guard_field: String?
    # @rbs guard_constant: String?
    # @rbs rhs_source_kind: Symbol
    # @rbs rhs_source_field: String?
    # @rbs rhs_constant: String?
    # @rbs state_field_updates: Array[Hash[Symbol, untyped]]
    # @rbs state_update_shape: Symbol
    # @rbs related_predicate_names: Array[String]
    # @rbs related_assertion_names: Array[String]
    # @rbs related_fact_names: Array[String]
    # @rbs related_pattern_hints: Array[Symbol]
    # @rbs derived_verify_hints: Array[Symbol]
    # @rbs return: void
    def initialize(predicate_name:, state_param_names: [], state_type: nil, argument_params: [], state_field: nil, state_field_multiplicity: nil, size_delta: nil, requires_non_empty_state: false, transition_kind: nil, result_position: nil, scalar_update_kind: nil, command_confidence: :low, guard: GuardAnalysis.new, guard_kind: :none, guard_field: nil, guard_constant: nil, rhs_source_kind: :unknown, rhs_source_field: nil, rhs_constant: nil, state_field_updates: [], state_update_shape: :unknown, related_predicate_names: [], related_assertion_names: [], related_fact_names: [], related_pattern_hints: [], derived_verify_hints: []) = super
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
      @guard_inferencer = GuardInferencer.new(@spec)
      @state_update_inferencer = StateUpdateInferencer.new(@spec)
      @related_hint_analyzer = RelatedHintAnalyzer.new(
        @spec,
        core_analysis_resolver: method(:core_analysis_for),
        normalized_body_resolver: method(:normalized_body_for),
        normalize_text_resolver: method(:normalize_text)
      )
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
      field_updates = @state_update_inferencer.infer_state_field_updates(
        body: body,
        predicate: predicate,
        state_param_names: state_param_names,
        state_type: state_type
      )
      fallback_state_field = infer_state_field(body, state_param_names)
      guard_kind, guard_field, guard_constant = @guard_inferencer.infer_guard_details(
        body: body,
        predicate: predicate,
        state_type: state_type,
        candidate_fields: field_updates.map { |item| item[:field] },
        fallback_state_field: fallback_state_field
      )
      primary_update = @state_update_inferencer.primary_state_update_for(field_updates, guard_field)
      collection_update = field_updates.find do |update|
        ["seq", "set"].include?(infer_state_field_multiplicity(state_type, update[:field]))
      end
      fallback_state_field_multiplicity = infer_state_field_multiplicity(state_type, fallback_state_field)
      prefer_collection_fallback = ["seq", "set"].include?(fallback_state_field_multiplicity) && !field_updates.empty?
      state_field =
        if collection_update
          collection_update[:field]
        elsif prefer_collection_fallback
          fallback_state_field
        else
          primary_update&.fetch(:field) || fallback_state_field
        end
      state_field_multiplicity =
        if collection_update
          infer_state_field_multiplicity(state_type, collection_update[:field])
        elsif prefer_collection_fallback
          fallback_state_field_multiplicity
        else
          infer_state_field_multiplicity(state_type, state_field)
        end
      size_delta = infer_size_delta(body)
      requires_non_empty_state = guard_kind == :non_empty
      transition_kind = infer_transition_kind(predicate.name, body, size_delta, requires_non_empty_state, state_field_multiplicity)
      scalar_update_kind = infer_scalar_update_kind(body, state_field, state_field_multiplicity)
      rhs_source_kind = primary_update&.fetch(:rhs_source_kind) || :unknown
      rhs_source_field = primary_update&.fetch(:rhs_source_field)
      rhs_constant = primary_update&.fetch(:rhs_constant)
      if primary_update.nil? || rhs_source_kind == :unknown
        rhs_source_kind, rhs_source_field, rhs_constant = @state_update_inferencer.infer_rhs_source_details(
          body: body,
          predicate: predicate,
          state_field: state_field,
          state_param_names: state_param_names
        )
      end
      state_update_shape = @state_update_inferencer.infer_state_update_shape(
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
        guard: @guard_inferencer.build_guard_analysis(
          guard_kind: guard_kind,
          guard_field: guard_field,
          guard_constant: guard_constant,
          argument_params: argument_params
        ),
        guard_kind: guard_kind,
        guard_field: guard_field,
        guard_constant: guard_constant,
        rhs_source_kind: rhs_source_kind,
        rhs_source_field: rhs_source_field,
        rhs_constant: rhs_constant,
        state_field_updates: field_updates,
        state_update_shape: state_update_shape
      )
      @analyses[predicate.name] = analysis

      @analyses[predicate.name] = analysis.with(**@related_hint_analyzer.enrich(predicate: predicate, analysis: analysis))
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
    # @rbs state_param_names: Array[String]
    # @rbs return: String?
    def infer_state_field(body, state_param_names)
      primed_names = state_param_names.select { |name| name.end_with?("'") }
      primed_names.each do |param_name|
        match = body.match(/##{Regexp.escape(param_name)}\.(\w+)/)
        return match[1] if match
      end

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
    # @rbs state_field_multiplicity: String?
    # @rbs return: Symbol?
    def infer_transition_kind(predicate_name, body, size_delta, requires_non_empty_state, state_field_multiplicity)
      return nil unless ["seq", "set"].include?(state_field_multiplicity)

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

      return :increment_like if body.match?(/#\w+'?\.#{Regexp.escape(state_field)}=(?:add\[#\w+\.#{Regexp.escape(state_field)},#?\w+\]|#\w+\.?#{Regexp.escape(state_field)}\+(?:1|#?\w+))/)
      return :decrement_like if body.match?(/#\w+'?\.#{Regexp.escape(state_field)}=(?:sub\[#\w+\.#{Regexp.escape(state_field)},#?\w+\]|#\w+\.?#{Regexp.escape(state_field)}-(?:1|#?\w+))/)
      return :replace_like if body.match?(/#\w+'?\.#{Regexp.escape(state_field)}=#?\w+/)

      nil
    end

    # @rbs predicate_name: String
    # @rbs transition_kind: Symbol?
    # @rbs size_delta: Integer?
    # @rbs requires_non_empty_state: bool
    # @rbs scalar_update_kind: Symbol?
    # @rbs state_update_shape: Symbol
    # @rbs return: Symbol
    def infer_command_confidence(predicate_name, transition_kind, size_delta, requires_non_empty_state, scalar_update_kind, state_update_shape)
      return :high if predicate_name.match?(/\A(?:Push|Pop|Enqueue|Dequeue|Add|Remove|Insert|Delete|Put|Get|Deposit|Withdraw|Credit|Debit)/)
      return :high if [:append, :pop, :dequeue].include?(transition_kind)
      return :high if [:append_like, :remove_first, :remove_last].include?(state_update_shape)
      return :medium if transition_kind == :size_no_change
      return :medium if [:increment, :decrement, :replace_with_arg, :replace_constant, :replace_value, :preserve_value].include?(state_update_shape)
      return :medium if !scalar_update_kind.nil?
      return :medium if !size_delta.nil? || requires_non_empty_state

      :low
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
