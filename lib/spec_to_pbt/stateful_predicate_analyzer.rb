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
      field_updates = infer_state_field_updates(body, predicate, state_param_names, state_type)
      fallback_state_field = infer_state_field(body, state_param_names)
      guard_candidates = state_field_candidates_for(state_type, field_updates.map { |item| item[:field] }, fallback_state_field)
      guard_kind, guard_field, guard_constant = infer_guard_details(body, predicate, guard_candidates, fallback_state_field)
      primary_update = primary_state_update_for(field_updates, guard_field)
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
        rhs_source_kind, rhs_source_field, rhs_constant = infer_rhs_source_details(body, predicate, state_field, state_param_names)
      end
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
        guard: guard_analysis_for(guard_kind, guard_field, guard_constant, argument_params),
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

    # @rbs guard_kind: Symbol
    # @rbs guard_field: String?
    # @rbs guard_constant: String?
    # @rbs argument_params: Array[Core::Parameter]
    # @rbs return: GuardAnalysis
    def guard_analysis_for(guard_kind, guard_field, guard_constant, argument_params)
      comparator =
        case guard_kind
        when :state_equals_constant then :eq
        when :arg_within_state then :lte
        when :non_empty, :below_capacity then :positive
        else nil
        end

      support_level =
        case guard_kind
        when :none then :none
        when :non_empty, :below_capacity, :arg_within_state, :state_equals_constant then :structural
        else :unsupported
        end

      GuardAnalysis.new(
        kind: guard_kind,
        field: guard_field,
        constant: guard_constant,
        comparator: comparator,
        argument_name: (guard_kind == :arg_within_state ? argument_params.first&.name : nil),
        support_level: support_level
      )
    end

    # @rbs body: String
    # @rbs predicate: Core::Entity
    # @rbs state_field: String?
    # @rbs return: [Symbol, String?, String?]
    def infer_guard_details(body, predicate, candidate_fields, fallback_state_field)
      guard_text = body.include?("implies") ? body.split("implies", 2).first.to_s : body

      non_empty_match = guard_text.match(/#\w+\.(\w+)\s*(?:>\s*0|>=\s*1)/)
      return [:non_empty, non_empty_match[1], nil] if non_empty_match

      capacity_match = guard_text.match(/#\w+\.(\w+)\s*<\s*#\w+\.(?:capacity|limit|max(?:imum)?)/i)
      return [:below_capacity, capacity_match[1], nil] if capacity_match

      state_constant_match = guard_text.match(/#\w+\.(\w+)\s*=\s*(-?\d+)\b/)
      return [:state_equals_constant, state_constant_match[1], state_constant_match[2]] if state_constant_match

      field_names = candidate_fields.compact.uniq
      field_names << fallback_state_field if fallback_state_field

      field_names.each do |field_name|
        next unless predicate.params.any? do |param|
          next false if param.name.end_with?("'")

          body.match?(/#\w+\.#{Regexp.escape(field_name)}\s*(?:>=|>)\s*#?#{Regexp.escape(param.name)}\b/)
        end

        return [:arg_within_state, field_name, nil]
      end

      [:none, fallback_state_field, nil]
    end

    # @rbs state_type: String?
    # @rbs candidate_fields: Array[String?]
    # @rbs fallback_state_field: String?
    # @rbs return: Array[String]
    def state_field_candidates_for(state_type, candidate_fields, fallback_state_field)
      names = candidate_fields.compact.uniq
      if state_type
        type_entity = @spec.types.find { |item| item.name == state_type }
        if type_entity
          names = (names + type_entity.fields.map(&:name)).uniq
        end
      end
      names << fallback_state_field if fallback_state_field
      names.compact.uniq
    end

    # @rbs field_updates: Array[Hash[Symbol, untyped]]
    # @rbs guard_field: String?
    # @rbs return: Hash[Symbol, untyped]?
    def primary_state_update_for(field_updates, guard_field)
      return nil if field_updates.empty?

      guarded_update = guard_field && field_updates.find { |update| update[:field] == guard_field }
      return guarded_update if guarded_update

      decrement_update = field_updates.find { |update| update[:update_shape] == :decrement && update[:rhs_source_kind] == :arg }
      return decrement_update if decrement_update

      field_updates.first
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

    # @rbs body: String
    # @rbs predicate: Core::Entity
    # @rbs state_param_names: Array[String]
    # @rbs state_type: String?
    # @rbs return: Array[Hash[Symbol, untyped]]
    def infer_state_field_updates(body, predicate, state_param_names, state_type)
      return [] unless state_type

      type_entity = @spec.types.find { |item| item.name == state_type }
      return [] unless type_entity

      primed_names = state_param_names.select { |name| name.end_with?("'") }
      param_names = primed_names.empty? ? state_param_names : primed_names
      updates = [] #: Array[Hash[Symbol, untyped]]

      param_names.each do |param_name|
        type_entity.fields.each do |field|
          pattern = /##{Regexp.escape(param_name)}\.#{Regexp.escape(field.name)}=(.+?)(?=(?:and|or)##{Regexp.escape(param_name)}\.|\z)/
          match = body.match(pattern)
          next unless match

          details = classify_state_field_update(
            rhs: match[1],
            target_field: field.name,
            predicate: predicate,
            state_param_names: state_param_names
          )
          updates << details.merge(field: field.name)
        end
      end

      updates.uniq { |item| item[:field] }
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

    # @rbs body: String
    # @rbs predicate: Core::Entity
    # @rbs state_field: String?
    # @rbs state_param_names: Array[String]
    # @rbs return: [Symbol, String?, String?]
    def infer_rhs_source_details(body, predicate, state_field, state_param_names)
      return [:unknown, nil, nil] if state_field.nil?

      predicate.params.each do |param|
        next if param.name.end_with?("'")
        next if state_param_names.include?(param.name)
        next if body.match?(/#\w+'?\.#{Regexp.escape(state_field)}=#?\w+\.#{Regexp.escape(state_field)}/)

        return [:arg, nil, nil] if body.match?(/#\w+'?\.#{Regexp.escape(state_field)}=#?#{Regexp.escape(param.name)}\b/)
        return [:arg, nil, nil] if body.match?(/#\w+'?\.#{Regexp.escape(state_field)}=(?:add|sub)\[#\w+\.#{Regexp.escape(state_field)},#?#{Regexp.escape(param.name)}\]/)
        return [:arg, nil, nil] if body.match?(/#\w+'?\.#{Regexp.escape(state_field)}=#\w+\.#{Regexp.escape(state_field)}[+-]#?#{Regexp.escape(param.name)}\b/)

        arg_field_match = body.match(/#\w+'?\.#{Regexp.escape(state_field)}=#?#{Regexp.escape(param.name)}\.(\w+)\b/)
        return [:arg_field, arg_field_match[1], nil] if arg_field_match
      end

      return [:state_field, state_field, nil] if body.match?(/#\w+'?\.#{Regexp.escape(state_field)}=#\w+\.#{Regexp.escape(state_field)}\b/)

      state_param_names.each do |param_name|
        source_match = body.match(/#\w+'?\.#{Regexp.escape(state_field)}=#?#{Regexp.escape(param_name)}\.(\w+)\b/)
        next unless source_match

        return [:state_field, source_match[1], nil]
      end

      constant_match = body.match(/#\w+'?\.#{Regexp.escape(state_field)}=(-?\d+)\b/)
      return [:constant, nil, constant_match[1]] if constant_match

      [:unknown, nil, nil]
    end

    # @rbs rhs: String
    # @rbs target_field: String
    # @rbs predicate: Core::Entity
    # @rbs state_param_names: Array[String]
    # @rbs return: Hash[Symbol, untyped]
    def classify_state_field_update(rhs:, target_field:, predicate:, state_param_names:)
      rhs = rhs.to_s.strip
      params_by_name = predicate.params.to_h { |param| [param.name, param] }

      if rhs.match?(/\A#\w+\.#{Regexp.escape(target_field)}\z/)
        return {
          update_shape: :preserve_value,
          rhs_source_kind: :state_field,
          rhs_source_field: target_field,
          rhs_constant: nil
        }
      end

      state_field_match = rhs.match(/\A#(\w+)\.(\w+)\z/)
      if state_field_match && state_param_names.include?(state_field_match[1])
        return {
          update_shape: (state_field_match[2] == target_field ? :preserve_value : :replace_value),
          rhs_source_kind: :state_field,
          rhs_source_field: state_field_match[2],
          rhs_constant: nil
        }
      end

      add_sub_match = rhs.match(/\A(add|sub)\[#\w+\.#{Regexp.escape(target_field)},#?(\w+)\]\z/)
      arithmetic_match = rhs.match(/\A#\w+\.#{Regexp.escape(target_field)}([+-])#?(\w+)\z/)
      if add_sub_match
        param_name = add_sub_match[2]
        return {
          update_shape: (add_sub_match[1] == "sub" ? :decrement : :increment),
          rhs_source_kind: (state_param_names.include?(param_name) ? :state_field : :arg),
          rhs_source_field: (state_param_names.include?(param_name) ? target_field : nil),
          rhs_constant: nil
        } if params_by_name.key?(param_name)
      end
      if arithmetic_match
        param_name = arithmetic_match[2]
        return {
          update_shape: (arithmetic_match[1] == "-" ? :decrement : :increment),
          rhs_source_kind: (state_param_names.include?(param_name) ? :state_field : :arg),
          rhs_source_field: (state_param_names.include?(param_name) ? target_field : nil),
          rhs_constant: nil
        } if params_by_name.key?(param_name)
      end

      return { update_shape: :increment, rhs_source_kind: :unknown, rhs_source_field: nil, rhs_constant: nil } if rhs.match?(/\A(?:add\[#\w+\.#{Regexp.escape(target_field)},1\]|#\w+\.#{Regexp.escape(target_field)}\+1)\z/)
      return { update_shape: :decrement, rhs_source_kind: :unknown, rhs_source_field: nil, rhs_constant: nil } if rhs.match?(/\A(?:sub\[#\w+\.#{Regexp.escape(target_field)},1\]|#\w+\.#{Regexp.escape(target_field)}-1)\z/)

      arg_field_match = rhs.match(/\A#?(\w+)\.(\w+)\z/)
      if arg_field_match && params_by_name.key?(arg_field_match[1]) && !state_param_names.include?(arg_field_match[1])
        return {
          update_shape: :replace_value,
          rhs_source_kind: :arg_field,
          rhs_source_field: arg_field_match[2],
          rhs_constant: nil
        }
      end

      if rhs.match?(/\A#?(\w+)\z/)
        param_name = Regexp.last_match(1)
        return {
          update_shape: :replace_with_arg,
          rhs_source_kind: :arg,
          rhs_source_field: nil,
          rhs_constant: nil
        } if params_by_name.key?(param_name) && !state_param_names.include?(param_name)
      end

      if rhs.match?(/\A-?\d+\z/)
        return {
          update_shape: :replace_constant,
          rhs_source_kind: :constant,
          rhs_source_field: nil,
          rhs_constant: rhs
        }
      end

      {
        update_shape: :unknown,
        rhs_source_kind: :unknown,
        rhs_source_field: nil,
        rhs_constant: nil
      }
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
      return :replace_constant if scalar_update_kind == :replace_like && rhs_source_kind == :constant
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
