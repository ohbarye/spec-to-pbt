# frozen_string_literal: true

# rbs_inline: enabled

module SpecToPbt
  class StatefulGenerator
    # Renders user-facing config suggestions without owning semantic generation.
    class SuggestionRenderer
      # @rbs generator: StatefulGenerator
      # @rbs return: void
      def initialize(generator)
        @generator = generator
      end

      # @rbs predicate_name: String
      # @rbs return: Array[Symbol]
      def api_method_names(predicate_name)
        suggestions = [] #: Array[Symbol]
        suggestions << :push if predicate_name.match?(/\APush/i)
        suggestions << :pop if predicate_name.match?(/\APop/i)
        suggestions << :enqueue if predicate_name.match?(/\AEnqueue/i)
        suggestions << :dequeue if predicate_name.match?(/\ADequeue/i)
        suggestions << :set_target if predicate_name.match?(/\ASetTarget/i)
        if predicate_name.match?(/\AHold/i)
          suggestions.concat([:authorize, :reserve, :place_hold])
        elsif predicate_name.match?(/\ACapture/i)
          suggestions.concat([:capture, :settle])
        elsif predicate_name.match?(/\ARelease/i)
          suggestions.concat([:release_hold, :void_authorization, :release])
        elsif predicate_name.match?(/\ATransfer/i)
          suggestions.concat([:move_funds, :transfer_amount, :post_transfer])
        end
        if predicate_name.match?(/\ADepositAmount/i)
          suggestions.concat([:credit, :deposit])
        elsif predicate_name.match?(/\ADeposit/i)
          suggestions.concat([:credit_one, :deposit, :credit])
        elsif predicate_name.match?(/\AWithdrawAmount/i)
          suggestions.concat([:debit, :withdraw])
        elsif predicate_name.match?(/\AWithdraw/i)
          suggestions.concat([:debit_one, :withdraw, :debit])
        end

        suggestions.uniq
      end

      # @rbs return: String
      def state_reader_comment
        analyses = selected_command_predicates.map { |predicate| predicate_analysis(predicate) }
        projection_analysis = analyses.find { |analysis| projection_collection_state?(analysis) }
        if projection_analysis
          fields = [projection_analysis.state_field, *collection_projection_updates_for(projection_analysis).map { |update| update[:field] }].uniq
          pairs = fields.map { |field| "#{field}: #{collection_observed_reader_expr(field)}" }
          return "suggested: ->(sut) { { #{pairs.join(', ')} } }"
        end

        return "suggested: ->(sut) { sut.snapshot }" if analyses.any? && analyses.all? { |analysis| collection_like_state?(analysis) }

        structured_analysis = analyses.find { |analysis| structured_collection_state?(analysis) }
        return "suggested: ->(sut) { sut.snapshot }" if structured_analysis

        structured_scalar_analysis = analyses.find { |analysis| structured_scalar_state?(analysis) }
        if structured_scalar_analysis
          fields = state_type_fields_for(structured_scalar_analysis)
          pairs = fields.map { |field| "#{field.name}: sut.#{field.name}" }
          return "suggested: ->(sut) { { #{pairs.join(', ')} } }"
        end

        scalar_field = single_scalar_state_field_for(analyses)
        if scalar_field
          return "suggested: ->(sut) { sut.#{scalar_field.name} }"
        end

        "suggested: expose a snapshot/reader for the model state"
      end

      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs return: String
      def verify_override_example(analysis)
        message = verify_override_message(analysis)
        if collection_like_state?(analysis)
          if projection_collection_state?(analysis)
            "->(after_state:, observed_state:, **) { raise \\\"#{message}\\\" unless observed_state == after_state }"
          elsif structured_collection_state?(analysis)
            "->(after_state:, observed_state:, **) { raise \\\"#{message}\\\" unless observed_state == after_state[:#{analysis.state_field}] }"
          else
            "->(after_state:, observed_state:, **) { raise \\\"#{message}\\\" unless observed_state == after_state }"
          end
        else
          "->(after_state:, observed_state:, **) { raise \\\"#{message}\\\" unless observed_state == after_state }"
        end
      end

      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs return: String
      def model_arg_adapter_example(_analysis)
        "->(args) { args }"
      end

      private

      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs return: String
      def verify_override_message(analysis)
        return "Expected observed collection state to match model" if collection_like_state?(analysis)
        return "Expected observed account balances to match model" if analysis.state_type&.match?(/Accounts/i)
        return "Expected observed balance to match model" if analysis.state_type&.match?(/Account|Wallet/i)
        return "Expected observed reservation state to match model" if analysis.state_type&.match?(/Reservation/i)

        "Expected observed state to match model"
      end

      def selected_command_predicates = call(:selected_command_predicates)
      def predicate_analysis(predicate) = call(:predicate_analysis, predicate)
      def projection_collection_state?(analysis) = call(:projection_collection_state?, analysis)
      def collection_projection_updates_for(analysis) = call(:collection_projection_updates_for, analysis)
      def collection_observed_reader_expr(field_name) = call(:collection_observed_reader_expr, field_name)
      def collection_like_state?(analysis) = call(:collection_like_state?, analysis)
      def structured_collection_state?(analysis) = call(:structured_collection_state?, analysis)
      def structured_scalar_state?(analysis) = call(:structured_scalar_state?, analysis)
      def state_type_fields_for(analysis) = call(:state_type_fields_for, analysis)
      def single_scalar_state_field_for(analyses) = call(:single_scalar_state_field_for, analyses)

      # @rbs method_name: Symbol
      # @rbs args: *untyped
      # @rbs return: untyped
      def call(method_name, *args)
        @generator.__send__(method_name, *args)
      end
    end
  end
end
