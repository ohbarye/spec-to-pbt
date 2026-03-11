# frozen_string_literal: true

# rbs_inline: enabled

module SpecToPbt
  class GuardInferencer
    # @rbs spec: Core::SpecDocument
    # @rbs return: void
    def initialize(spec)
      @spec = spec
    end

    # @rbs body: String
    # @rbs predicate: Core::Entity
    # @rbs state_type: String?
    # @rbs candidate_fields: Array[String?]
    # @rbs fallback_state_field: String?
    # @rbs return: [Symbol, String?, String?]
    def infer_guard_details(body:, predicate:, state_type:, candidate_fields:, fallback_state_field:)
      guard_text = body.include?("implies") ? body.split("implies", 2).first.to_s : body

      non_empty_match = guard_text.match(/#\w+\.(\w+)\s*(?:>\s*0|>=\s*1)/)
      return [:non_empty, non_empty_match[1], nil] if non_empty_match

      capacity_match = guard_text.match(/#\w+\.(\w+)\s*<\s*#\w+\.(?:capacity|limit|max(?:imum)?)/i)
      return [:below_capacity, capacity_match[1], nil] if capacity_match

      state_constant_match = guard_text.match(/#\w+\.(\w+)\s*=\s*(-?\d+)\b/)
      return [:state_equals_constant, state_constant_match[1], state_constant_match[2]] if state_constant_match

      state_field_candidates_for(state_type, candidate_fields, fallback_state_field).each do |field_name|
        next unless predicate.params.any? do |param|
          next false if param.name.end_with?("'")

          body.match?(/#\w+\.#{Regexp.escape(field_name)}\s*(?:>=|>)\s*#?#{Regexp.escape(param.name)}\b/)
        end

        return [:arg_within_state, field_name, nil]
      end

      [:none, fallback_state_field, nil]
    end

    # @rbs guard_kind: Symbol
    # @rbs guard_field: String?
    # @rbs guard_constant: String?
    # @rbs argument_params: Array[Core::Parameter]
    # @rbs return: GuardAnalysis
    def build_guard_analysis(guard_kind:, guard_field:, guard_constant:, argument_params:)
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

    private

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
  end
end
