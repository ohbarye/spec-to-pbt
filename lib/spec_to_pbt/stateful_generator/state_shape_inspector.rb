# frozen_string_literal: true

# rbs_inline: enabled

module SpecToPbt
  class StatefulGenerator
    # Classifies generated model-state shapes and related access/update helpers.
    class StateShapeInspector
      # @rbs generator: StatefulGenerator
      # @rbs return: void
      def initialize(generator)
        @generator = generator
      end

      # @rbs analysis: StatefulPredicateAnalysis?
      # @rbs return: bool
      def structured_collection_state?(analysis)
        return false unless analysis
        return false unless collection_like_state?(analysis)

        stable_companion_collection_state?(analysis) || projection_collection_state?(analysis)
      end

      # @rbs analysis: StatefulPredicateAnalysis?
      # @rbs return: bool
      def stable_companion_collection_state?(analysis)
        return false unless analysis
        return false unless collection_like_state?(analysis)

        companion_scalar_fields_for(analysis).any? { |field| stable_companion_scalar_field?(field) }
      end

      # @rbs analysis: StatefulPredicateAnalysis?
      # @rbs return: bool
      def projection_collection_state?(analysis)
        return false unless analysis
        return false unless collection_like_state?(analysis)

        projection_plan_for(analysis).support_level == :structural
      end

      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs return: Array[Core::Field]
      def companion_scalar_fields_for(analysis)
        return [] unless analysis.state_type

        type_entity = spec.types.find { |item| item.name == analysis.state_type }
        return [] unless type_entity

        type_entity.fields.reject do |field|
          field.name == analysis.state_field || ["seq", "set"].include?(field.multiplicity)
        end
      end

      # @rbs analysis: StatefulPredicateAnalysis?
      # @rbs return: bool
      def structured_scalar_state?(analysis)
        return false unless analysis
        return false if collection_like_state?(analysis)

        fields = state_type_fields_for(analysis)
        return false if fields.empty?
        return false if fields.any? { |field| ["seq", "set"].include?(field.multiplicity) }

        return true if fields.length > 1

        companions = companion_scalar_fields_for(analysis)
        return false if companions.empty?

        companions.all? { |field| stable_companion_scalar_field?(field) }
      end

      # @rbs analyses: Array[StatefulPredicateAnalysis]
      # @rbs return: Core::Field?
      def single_scalar_state_field_for(analyses)
        state_types = analyses.map(&:state_type).compact.uniq
        return nil unless state_types.length == 1

        state_fields = analyses.map(&:state_field).compact.uniq
        return nil unless state_fields.length == 1

        type_entity = spec.types.find { |item| item.name == state_types.first }
        return nil unless type_entity
        return nil unless type_entity.fields.length == 1

        field = type_entity.fields.first
        return nil if ["seq", "set"].include?(field.multiplicity)
        return nil unless field.name == state_fields.first

        field
      end

      # @rbs field: Core::Field
      # @rbs return: String
      def default_scalar_placeholder_for(field)
        return "3" if field.name.match?(/capacity|limit|max(?:imum)?/i)
        return "0" if field.type == "Int"
        return "nil" if field.multiplicity == "lone"

        "nil"
      end

      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs return: Array[Core::Field]
      def state_type_fields_for(analysis)
        return [] unless analysis.state_type

        type_entity = spec.types.find { |item| item.name == analysis.state_type }
        type_entity ? type_entity.fields : []
      end

      # @rbs field: Core::Field
      # @rbs return: bool
      def stable_companion_scalar_field?(field)
        field.name.match?(/capacity|limit|max(?:imum)?|minimum|min(?:imum)?|threshold|floor|ceiling/i)
      end

      # @rbs state_var: String
      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs return: String
      def collection_state_expr(state_var, analysis)
        if structured_collection_state?(analysis)
          "#{state_var}[:#{analysis.state_field}]"
        else
          state_var
        end
      end

      # @rbs state_var: String
      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs return: String?
      def capacity_state_expr(state_var, analysis)
        field = companion_scalar_fields_for(analysis).find { |item| item.name.match?(/capacity|limit|max(?:imum)?/i) }
        return nil unless field

        "#{state_var}[:#{field.name}]"
      end

      # @rbs state_var: String
      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs return: String
      def scalar_state_expr(state_var, analysis)
        if structured_scalar_state?(analysis)
          "#{state_var}[:#{analysis.state_field}]"
        else
          state_var
        end
      end

      # @rbs state_var: String
      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs return: String
      def guard_state_expr(state_var, analysis)
        field_name = guard_for(analysis).field || analysis.state_field
        if structured_scalar_state?(analysis) || structured_collection_state?(analysis)
          "#{state_var}[:#{field_name}]"
        else
          state_var
        end
      end

      # @rbs state_var: String
      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs return: String
      def scalar_argument_domain_expr(state_var, analysis)
        guard_state_expr(state_var, analysis)
      end

      # @rbs state_var: String
      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs updated_scalar_expr: String
      # @rbs return: String
      def scalar_state_update_expr(state_var, analysis, updated_scalar_expr)
        if structured_scalar_state?(analysis)
          "#{state_var}.merge(#{analysis.state_field}: #{updated_scalar_expr})"
        else
          updated_scalar_expr
        end
      end

      # @rbs state_var: String
      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs updated_collection_expr: String
      # @rbs return: String
      def collection_state_update_expr(state_var, analysis, updated_collection_expr)
        if structured_collection_state?(analysis)
          "#{state_var}.merge(#{analysis.state_field}: #{updated_collection_expr})"
        else
          updated_collection_expr
        end
      end

      # @rbs field_name: String
      # @rbs return: String
      def collection_observed_reader_expr(field_name)
        if field_name.match?(/\Aentries|elements|items|values|jobs|adjustments|movements|events|captures/i)
          "sut.#{field_name}.dup"
        else
          "sut.#{field_name}"
        end
      end

      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs field_name: String
      # @rbs return: bool
      def numeric_scalar_field_name?(analysis, field_name)
        return false unless analysis.state_type

        type_entity = spec.types.find { |item| item.name == analysis.state_type }
        return false unless type_entity

        field = type_entity.fields.find { |item| item.name == field_name }
        field&.type == "Int"
      end

      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs return: bool
      def numeric_scalar_state?(analysis)
        return false unless analysis.state_type && analysis.state_field

        type_entity = spec.types.find { |item| item.name == analysis.state_type }
        return false unless type_entity

        field = type_entity.fields.find { |item| item.name == analysis.state_field }
        field&.type == "Int"
      end

      private

      def spec = call(:spec_document)
      def collection_like_state?(analysis) = call(:collection_like_state?, analysis)
      def projection_plan_for(analysis) = call(:projection_plan_for, analysis)
      def guard_for(analysis) = call(:guard_for, analysis)

      # @rbs method_name: Symbol
      # @rbs args: *untyped
      # @rbs return: untyped
      def call(method_name, *args)
        @generator.__send__(method_name, *args)
      end
    end
  end
end
