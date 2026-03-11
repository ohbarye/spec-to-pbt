# frozen_string_literal: true

# rbs_inline: enabled

module SpecToPbt
  class StatefulGenerator
    # Render-facing normalization of a command predicate and its analysis.
    class CommandPlan
      attr_reader :predicate, :analysis, :behavior, :method_name, :class_name, :body_preview,
                  :arg_aware_applicability, :guard_supportable

      # @rbs predicate: Core::Entity
      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs behavior: Symbol
      # @rbs method_name: String
      # @rbs class_name: String
      # @rbs body_preview: String
      # @rbs arg_aware_applicability: bool
      # @rbs guard_supportable: bool
      # @rbs return: void
      def initialize(predicate:, analysis:, behavior:, method_name:, class_name:, body_preview:, arg_aware_applicability:, guard_supportable:)
        @predicate = predicate
        @analysis = analysis
        @behavior = behavior
        @method_name = method_name
        @class_name = class_name
        @body_preview = body_preview
        @arg_aware_applicability = arg_aware_applicability
        @guard_supportable = guard_supportable
      end
    end
  end
end
