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
        lines << "# Edit this file to map spec command names to your real Ruby API and observed-state checks."
        lines << "# This file is user-owned and should not be overwritten automatically."
        lines << "#"
        lines << "# Required fields (search for TODO(required) to find them):"
        lines << "#   sut_factory                   - how to create the system under test"
        lines << "#   command_mappings.*.method      - real Ruby method name for each command"
        lines << "#   verify_context.state_reader    - how to read observable state from the SUT"
        lines << "#"
        lines << "# Optional fields:"
        lines << "#   initial_state                  - override when inferred model baseline does not match SUT defaults"
        lines << "#   arg_adapter / model_arg_adapter - transform arguments for SUT or model"
        lines << "#   result_adapter                 - normalize SUT return values"
        lines << "#   arguments_override             - custom argument generator for invalid-path coverage"
        lines << "#   applicable_override            - override command applicability"
        lines << "#   next_state_override            - override model transition"
        lines << "#   verify_override                - override verification logic"
        lines << "#   guard_failure_policy           - :no_op / :raise / :custom for guard failures"
        lines << "#   before_run / after_run         - hooks around each command execution"
        lines << "#"
        lines << "# See docs/config-reference.md for full field documentation."
        lines << ""
        lines << "#{config_constant_name} = {"
        lines << "  sut_factory: -> { raise \"TODO(required): replace with your SUT, e.g. YourClass.new\" },"
        lines << "  # initial_state: #{initial_state_config_example}, # optional: set this when the inferred model baseline does not match your SUT defaults"
        lines << "  command_mappings: {"
        selected_command_predicates.each_with_index do |predicate, index|
          suffix = index == selected_command_predicates.length - 1 ? "" : ","
          lines.concat(config_command_lines(predicate, suffix))
        end
        lines << "  },"
        lines << "  verify_context: {"
        lines << "    state_reader: nil, # TODO(required): #{@suggestions.state_reader_comment} — without this, SUT state is not compared against the model"
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
        normalized_methods = suggested_methods - [method_name.to_sym]
        method_suggestion = normalized_methods.any? ? " (suggested: #{normalized_methods.map { |name| ":#{name}" }.join(', ')})" : ""
        lines = [
          "    #{method_name}: {",
          "      method: :#{method_name}, # TODO(required): replace with real method name#{method_suggestion}"
        ]
        lines << "      # arg_adapter: ->(args) { args }, # use when the Ruby API wants a different runtime argument shape"
        lines << "      # model_arg_adapter: #{@suggestions.model_arg_adapter_example(analysis)}"
        lines << "      # result_adapter: ->(result) { result }, # use when the SUT result needs normalization before verify!"
        lines << "      # arguments_override: #{@suggestions.arguments_override_example(predicate, analysis)}, # optional 0-arity/1-arity generator override for invalid-path coverage or custom distributions"
        lines << "      # applicable_override: ->(state, args = nil) { true }, # use this for unsupported guards, richer domain preconditions, or to deliberately drive invalid calls"
        if analysis.derived_verify_hints.include?(:check_guard_failure_semantics)
          lines << "      # guard_failure_policy: :no_op, # or :raise / :custom"
          lines << "      # Suggested failure/no-op handling: use :no_op for unchanged-state invalid calls, :raise for captured exceptions, or :custom with verify_override when the invalid path is domain-specific"
          lines << "      # Note: leave inferred arguments(state) in place for valid-path coverage; add arguments_override only when you need out-of-range args or a custom invalid-path distribution."
          lines << "      # #{@suggestions.invalid_path_recipe_comment(predicate, analysis)}"
        end
        lines << "      # next_state_override: ->(state, args) { state }, # use this when invalid paths or derived state need a domain-specific model transition"
        lines << "      # verify_override: #{@suggestions.verify_override_example(analysis)} # leave this commented out when state_reader already exposes the model-shaped observed state; enable it for custom postconditions or invalid-path semantics"
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
