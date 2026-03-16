# frozen_string_literal: true

# rbs_inline: enabled

module SpecToPbt
  class StateUpdateInferencer
    # @rbs spec: Core::SpecDocument
    # @rbs return: void
    def initialize(spec)
      @spec = spec
    end

    # @rbs body: String
    # @rbs predicate: Core::Entity
    # @rbs state_param_names: Array[String]
    # @rbs state_type: String?
    # @rbs return: Array[Hash[Symbol, untyped]]
    def infer_state_field_updates(body:, predicate:, state_param_names:, state_type:)
      semantic_updates = semantic_state_updates_for(predicate)
      return semantic_updates unless semantic_updates.empty?

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
    # @rbs predicate: Core::Entity
    # @rbs state_field: String?
    # @rbs state_param_names: Array[String]
    # @rbs return: [Symbol, String?, String?]
    def infer_rhs_source_details(body:, predicate:, state_field:, state_param_names:)
      semantic_update = primary_semantic_update(predicate, state_field)
      if semantic_update
        return [
          semantic_update[:rhs_source_kind] || :unknown,
          semantic_update[:rhs_source_field],
          semantic_update[:rhs_constant]&.to_s
        ]
      end

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

    private

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

    # @rbs predicate: Core::Entity
    # @rbs return: Array[Hash[Symbol, untyped]]
    def semantic_state_updates_for(predicate)
      hints = predicate.metadata[:semantic_hints]
      updates = hints && hints[:state_updates]
      return [] unless updates

      updates.map do |update|
        {
          field: update[:field],
          update_shape: update[:update_shape],
          rhs_source_kind: update[:rhs_source_kind] || :unknown,
          rhs_source_field: update[:rhs_source_field],
          rhs_constant: update[:rhs_constant]&.to_s
        }
      end
    end

    # @rbs predicate: Core::Entity
    # @rbs state_field: String?
    # @rbs return: Hash[Symbol, untyped]?
    def primary_semantic_update(predicate, state_field)
      updates = predicate.metadata[:semantic_hints] && predicate.metadata[:semantic_hints][:state_updates]
      return nil unless updates && !updates.empty?

      if state_field
        matching = updates.find { |update| update[:field] == state_field }
        return matching if matching
      end

      updates.first
    end
  end
end
