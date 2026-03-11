# frozen_string_literal: true

# rbs_inline: enabled

module SpecToPbt
  class StatefulGenerator
    # Render-facing plan for append-only projection patterns.
    class ProjectionPlan
      attr_reader :analysis, :updates, :append_item_expr, :needs_delta, :support_level

      # @rbs generator: StatefulGenerator
      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs return: void
      def initialize(generator, analysis)
        @generator = generator
        @analysis = analysis
        @updates = infer_updates
        @append_item_expr = infer_append_item_expr
        @needs_delta = @updates.any? { |update| update[:rhs_source_kind] == :arg } || @append_item_expr.include?("delta")
        @support_level = @updates.empty? ? :none : :structural
      end

      private

      # @rbs return: Array[Hash[Symbol, untyped]]
      def infer_updates
        return [] unless analysis
        return [] unless collection_like_state?(analysis)

        scalar_field_updates_for(analysis).select do |update|
          update[:field] != analysis.state_field &&
            [:increment, :decrement, :replace_with_arg, :replace_value, :replace_constant, :preserve_value].include?(update[:update_shape])
        end
      end

      # @rbs return: String
      def infer_append_item_expr
        update =
          updates.find { |item| item[:update_shape] == :increment && item[:rhs_source_kind] == :arg } ||
          updates.find { |item| item[:update_shape] == :replace_with_arg } ||
          updates.find { |item| item[:update_shape] == :increment } ||
          updates.find { |item| item[:rhs_source_kind] == :arg } ||
          updates.find { |item| item[:update_shape] != :preserve_value } ||
          updates.first
        return "args" unless update

        case update[:update_shape]
        when :increment
          update[:rhs_source_kind] == :arg ? "delta" : "1"
        when :decrement
          update[:rhs_source_kind] == :arg ? "-delta" : "-1"
        when :replace_with_arg
          "#{support_module_name}.scalar_model_arg(name, args)"
        when :replace_constant
          update[:rhs_constant] || "args"
        else
          "args"
        end
      end

      def collection_like_state?(analysis) = call(:collection_like_state?, analysis)
      def scalar_field_updates_for(analysis) = call(:scalar_field_updates_for, analysis)
      def support_module_name = call(:support_module_name)

      # @rbs method_name: Symbol
      # @rbs args: *untyped
      # @rbs return: untyped
      def call(method_name, *args)
        @generator.__send__(method_name, *args)
      end
    end
  end
end
