# frozen_string_literal: true

# rbs_inline: enabled

module SpecToPbt
  class StatefulGenerator
    # Render-facing normalization of a command predicate and its analysis.
    class CommandPlan
      attr_reader :predicate, :analysis, :behavior, :method_name, :class_name, :body_preview,
                  :arg_aware_applicability, :guard_supportable, :state_shape, :next_state_mode

      # @rbs predicate: Core::Entity
      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs behavior: Symbol
      # @rbs method_name: String
      # @rbs class_name: String
      # @rbs body_preview: String
      # @rbs arg_aware_applicability: bool
      # @rbs guard_supportable: bool
      # @rbs state_shape: Symbol
      # @rbs next_state_mode: Symbol
      # @rbs return: void
      def initialize(predicate:, analysis:, behavior:, method_name:, class_name:, body_preview:, arg_aware_applicability:, guard_supportable:, state_shape:, next_state_mode:)
        @predicate = predicate
        @analysis = analysis
        @behavior = behavior
        @method_name = method_name
        @class_name = class_name
        @body_preview = body_preview
        @arg_aware_applicability = arg_aware_applicability
        @guard_supportable = guard_supportable
        @state_shape = state_shape
        @next_state_mode = next_state_mode
      end

      # @rbs return: bool
      def arg_aware_applicability? = @arg_aware_applicability

      # @rbs return: bool
      def guard_supportable? = @guard_supportable

      # @rbs return: bool
      def collection_state? = [:collection, :structured_collection, :projection_collection].include?(@state_shape)

      # @rbs return: bool
      def scalar_state? = !collection_state?

      # @rbs return: bool
      def structured_collection_state? = [:structured_collection, :projection_collection].include?(@state_shape)

      # @rbs return: bool
      def structured_scalar_state? = @state_shape == :structured_scalar

      # @rbs return: bool
      def projection_state? = @state_shape == :projection_collection

      # @rbs return: bool
      def guarded? = analysis.guard_kind != :none

      # @rbs return: String
      def guard_signature
        arg_aware_applicability? ? "state, args = nil" : "state, _args = nil"
      end
    end
  end
end
