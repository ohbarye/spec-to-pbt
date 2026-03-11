# frozen_string_literal: true

# rbs_inline: enabled

module SpecToPbt
  class StatefulGenerator
    # Renders the regeneration-safe companion config for stateful scaffolds.
    class ConfigRenderer
      # @rbs generator: StatefulGenerator
      # @rbs return: void
      def initialize(generator)
        @generator = generator
      end

      # @rbs return: String
      def render
        lines = [] #: Array[String]
        lines << "# frozen_string_literal: true"
        lines << ""
        lines << "# Regeneration-safe customization file for #{module_name} stateful scaffold."
        lines << "# Edit this file to map spec command names to your real Ruby API."
        lines << "# This file is user-owned and should not be overwritten automatically."
        lines << ""
        lines << "#{config_constant_name} = {"
        lines << "  sut_factory: -> { #{sut_factory_code} },"
        lines << "  # initial_state: #{initial_state_config_example},"
        lines << "  command_mappings: {"
        selected_command_predicates.each_with_index do |predicate, index|
          suffix = index == selected_command_predicates.length - 1 ? "" : ","
          lines.concat(config_command_lines(predicate, suffix))
        end
        lines << "  },"
        lines << "  verify_context: {"
        lines << "    state_reader: nil, # #{suggested_state_reader_comment}"
        lines << "  }"
        lines << "  # before_run: ->(sut) { },"
        lines << "  # after_run: ->(sut, result) { }"
        lines << "}"
        lines.join("\n")
      end

      private

      # @rbs predicate: Core::Entity
      # @rbs suffix: String
      # @rbs return: Array[String]
      def config_command_lines(predicate, suffix)
        method_name = method_name_for(predicate)
        analysis = predicate_analysis(predicate)
        suggested_methods = suggested_api_method_names(predicate.name)
        lines = [
          "    #{method_name}: {",
          "      method: :#{method_name},"
        ]
        normalized_methods = suggested_methods - [method_name.to_sym]
        if normalized_methods.any?
          lines << "      # Suggested real API methods: #{normalized_methods.map { |name| ":#{name}" }.join(', ')}"
        end
        lines << "      # arg_adapter: ->(args) { args },"
        lines << "      # model_arg_adapter: #{suggested_model_arg_adapter_example(analysis)}"
        lines << "      # result_adapter: ->(result) { result },"
        lines << "      # applicable_override: ->(state, args = nil) { true }, # use this for unsupported guards or richer domain preconditions"
        lines << "      # next_state_override: ->(state, args) { state }, # use this when invalid paths or derived state need a domain-specific model transition"
        if analysis.derived_verify_hints.include?(:check_guard_failure_semantics)
          lines << "      # guard_failure_policy: :no_op, # or :raise / :custom"
          lines << "      # Suggested failure/no-op handling: use :no_op for unchanged-state invalid calls, :raise for captured exceptions, or :custom with verify_override when the invalid path is domain-specific"
        end
        lines << "      # verify_override: #{suggested_verify_override_example(analysis)} # use this for observed-state checks and lifecycle/business-rule-heavy invalid-path semantics"
        lines << "    }#{suffix}"
        lines
      end

      # @rbs predicate_name: String
      # @rbs return: Array[Symbol]
      def suggested_api_method_names(predicate_name)
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
      def suggested_state_reader_comment
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
      def suggested_verify_override_example(analysis)
        message = suggested_verify_override_message(analysis)
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
      def suggested_model_arg_adapter_example(_analysis)
        "->(args) { args }"
      end

      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs return: String
      def suggested_verify_override_message(analysis)
        return "Expected observed collection state to match model" if collection_like_state?(analysis)
        return "Expected observed account balances to match model" if analysis.state_type&.match?(/Accounts/i)
        return "Expected observed balance to match model" if analysis.state_type&.match?(/Account|Wallet/i)
        return "Expected observed reservation state to match model" if analysis.state_type&.match?(/Reservation/i)

        "Expected observed state to match model"
      end

      # @rbs return: String
      def module_name
        call(:module_name)
      end

      # @rbs return: String
      def config_constant_name
        call(:config_constant_name)
      end

      # @rbs return: String
      def sut_factory_code
        call(:sut_factory_code)
      end

      # @rbs return: String
      def initial_state_config_example
        call(:initial_state_config_example)
      end

      # @rbs return: Array[Core::Entity]
      def selected_command_predicates
        call(:selected_command_predicates)
      end

      # @rbs predicate: Core::Entity
      # @rbs return: StatefulPredicateAnalysis
      def predicate_analysis(predicate)
        call(:predicate_analysis, predicate)
      end

      # @rbs predicate: Core::Entity
      # @rbs return: String
      def method_name_for(predicate)
        call(:method_name_for, predicate)
      end

      # @rbs analysis: StatefulPredicateAnalysis?
      # @rbs return: bool
      def collection_like_state?(analysis)
        call(:collection_like_state?, analysis)
      end

      # @rbs analysis: StatefulPredicateAnalysis?
      # @rbs return: bool
      def projection_collection_state?(analysis)
        call(:projection_collection_state?, analysis)
      end

      # @rbs analysis: StatefulPredicateAnalysis?
      # @rbs return: bool
      def structured_collection_state?(analysis)
        call(:structured_collection_state?, analysis)
      end

      # @rbs analysis: StatefulPredicateAnalysis?
      # @rbs return: bool
      def structured_scalar_state?(analysis)
        call(:structured_scalar_state?, analysis)
      end

      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs return: Array[Core::Field]
      def state_type_fields_for(analysis)
        call(:state_type_fields_for, analysis)
      end

      # @rbs analyses: Array[StatefulPredicateAnalysis]
      # @rbs return: Core::Field?
      def single_scalar_state_field_for(analyses)
        call(:single_scalar_state_field_for, analyses)
      end

      # @rbs analysis: StatefulPredicateAnalysis?
      # @rbs return: Array[Hash[Symbol, untyped]]
      def collection_projection_updates_for(analysis)
        call(:collection_projection_updates_for, analysis)
      end

      # @rbs field_name: String
      # @rbs return: String
      def collection_observed_reader_expr(field_name)
        call(:collection_observed_reader_expr, field_name)
      end

      # @rbs method_name: Symbol
      # @rbs args: *untyped
      # @rbs return: untyped
      def call(method_name, *args)
        @generator.__send__(method_name, *args)
      end
    end
  end
end
