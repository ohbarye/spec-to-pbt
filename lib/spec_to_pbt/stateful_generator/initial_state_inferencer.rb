# frozen_string_literal: true

# rbs_inline: enabled

module SpecToPbt
  class StatefulGenerator
    # Infers default initial model state examples for generated scaffolds/configs.
    class InitialStateInferencer
      # @rbs generator: StatefulGenerator
      # @rbs return: void
      def initialize(generator)
        @generator = generator
      end

      # @rbs return: String
      def scaffold_code
        analyses = selected_command_predicates.map { |predicate| predicate_analysis(predicate) }
        return "[] # TODO: replace with a domain-specific model state" if analyses.empty?
        if analyses.all? { |analysis| collection_like_state?(analysis) }
          structured_analysis = analyses.find { |analysis| structured_collection_state?(analysis) }
          return structured_collection_initial_state_code(structured_analysis) if structured_analysis

          return "[] # TODO: replace with a domain-specific collection state"
        end

        structured_scalar_analysis = analyses.find { |analysis| structured_scalar_state?(analysis) }
        return structured_scalar_initial_state_code(structured_scalar_analysis) if structured_scalar_analysis

        scalar_field = single_scalar_state_field_for(analyses)
        if scalar_field
          return "#{default_scalar_placeholder_for(scalar_field)} # TODO: replace with a domain-specific scalar model state"
        end

        "nil # TODO: replace with a domain-specific scalar/model state"
      end

      # @rbs return: String
      def config_example
        analyses = selected_command_predicates.map { |predicate| predicate_analysis(predicate) }
        return "[]" if analyses.empty?
        if analyses.all? { |analysis| collection_like_state?(analysis) }
          structured_analysis = analyses.find { |analysis| structured_collection_state?(analysis) }
          return "{ #{structured_collection_example_pairs(structured_analysis).join(', ')} }" if structured_analysis

          return "[]"
        end

        structured_scalar_analysis = analyses.find { |analysis| structured_scalar_state?(analysis) }
        return "{ #{structured_state_example_pairs(structured_scalar_analysis).join(', ')} }" if structured_scalar_analysis

        scalar_field = single_scalar_state_field_for(analyses)
        return default_scalar_placeholder_for(scalar_field) if scalar_field

        "nil"
      end

      private

      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs return: String
      def structured_collection_initial_state_code(analysis)
        pairs = [] #: Array[String]
        pairs << "#{analysis.state_field}: []"
        companion_scalar_fields_for(analysis).each do |field|
          pairs << "#{field.name}: #{default_scalar_placeholder_for(field)}"
        end

        "{ #{pairs.join(', ')} } # TODO: replace with a domain-specific structured model state"
      end

      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs return: String
      def structured_scalar_initial_state_code(analysis)
        pairs = state_type_fields_for(analysis).map do |field|
          "#{field.name}: #{default_scalar_placeholder_for(field)}"
        end

        "{ #{pairs.join(', ')} } # TODO: replace with a domain-specific structured model state"
      end

      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs return: Array[String]
      def structured_state_example_pairs(analysis)
        state_type_fields_for(analysis).map do |field|
          "#{field.name}: #{default_scalar_placeholder_for(field)}"
        end
      end

      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs return: Array[String]
      def structured_collection_example_pairs(analysis)
        state_type_fields_for(analysis).map do |field|
          if field.name == analysis.state_field
            "#{field.name}: []"
          else
            "#{field.name}: #{default_scalar_placeholder_for(field)}"
          end
        end
      end

      def selected_command_predicates = call(:selected_command_predicates)
      def predicate_analysis(predicate) = call(:predicate_analysis, predicate)
      def collection_like_state?(analysis) = call(:collection_like_state?, analysis)
      def structured_collection_state?(analysis) = call(:structured_collection_state?, analysis)
      def structured_scalar_state?(analysis) = call(:structured_scalar_state?, analysis)
      def single_scalar_state_field_for(analyses) = call(:single_scalar_state_field_for, analyses)
      def default_scalar_placeholder_for(field) = call(:default_scalar_placeholder_for, field)
      def companion_scalar_fields_for(analysis) = call(:companion_scalar_fields_for, analysis)
      def state_type_fields_for(analysis) = call(:state_type_fields_for, analysis)

      # @rbs method_name: Symbol
      # @rbs args: *untyped
      # @rbs return: untyped
      def call(method_name, *args)
        @generator.__send__(method_name, *args)
      end
    end
  end
end
