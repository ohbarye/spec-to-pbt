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
        @suggestions = SuggestionRenderer.new(generator)
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
        lines << "    state_reader: nil, # #{@suggestions.state_reader_comment}"
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
        suggested_methods = @suggestions.api_method_names(predicate.name)
        lines = [
          "    #{method_name}: {",
          "      method: :#{method_name},"
        ]
        normalized_methods = suggested_methods - [method_name.to_sym]
        if normalized_methods.any?
          lines << "      # Suggested real API methods: #{normalized_methods.map { |name| ":#{name}" }.join(', ')}"
        end
        lines << "      # arg_adapter: ->(args) { args },"
        lines << "      # model_arg_adapter: #{@suggestions.model_arg_adapter_example(analysis)}"
        lines << "      # result_adapter: ->(result) { result },"
        lines << "      # applicable_override: ->(state, args = nil) { true }, # use this for unsupported guards or richer domain preconditions"
        lines << "      # next_state_override: ->(state, args) { state }, # use this when invalid paths or derived state need a domain-specific model transition"
        if analysis.derived_verify_hints.include?(:check_guard_failure_semantics)
          lines << "      # guard_failure_policy: :no_op, # or :raise / :custom"
          lines << "      # Suggested failure/no-op handling: use :no_op for unchanged-state invalid calls, :raise for captured exceptions, or :custom with verify_override when the invalid path is domain-specific"
        end
        lines << "      # verify_override: #{@suggestions.verify_override_example(analysis)} # use this for observed-state checks and lifecycle/business-rule-heavy invalid-path semantics"
        lines << "    }#{suffix}"
        lines
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

      # @rbs method_name: Symbol
      # @rbs args: *untyped
      # @rbs return: untyped
      def call(method_name, *args)
        @generator.__send__(method_name, *args)
      end
    end
  end
end
