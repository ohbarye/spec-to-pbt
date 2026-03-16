# frozen_string_literal: true

# rbs_inline: enabled

module SpecToPbt
  class StatefulGenerator
    # Renders verify! bodies for generated stateful commands.
    class VerifyRenderer
      # @rbs generator: StatefulGenerator
      # @rbs return: void
      def initialize(generator)
        @generator = generator
      end

      # @rbs plan: CommandPlan
      # @rbs return: Array[String]
      def render_lines(plan)
        analysis = plan.analysis
        behavior = plan.behavior
        body_preview = plan.body_preview
        lines = [
          "    def verify!(before_state:, after_state:, args:, result:, sut:)",
          "      # TODO: translate predicate semantics into postcondition checks",
          "      # Alloy predicate body (preview): #{body_preview.inspect}",
          "      # Analyzer hints: state_field=#{analysis.state_field.inspect}, size_delta=#{analysis.size_delta.inspect}, transition_kind=#{analysis.transition_kind.inspect}, requires_non_empty_state=#{analysis.requires_non_empty_state}, scalar_update_kind=#{analysis.scalar_update_kind.inspect}, command_confidence=#{analysis.command_confidence.inspect}, guard_kind=#{analysis.guard_kind.inspect}, guard_field=#{analysis.guard_field.inspect}, guard_constant=#{analysis.guard_constant.inspect}, rhs_source_kind=#{analysis.rhs_source_kind.inspect}, state_update_shape=#{analysis.state_update_shape.inspect}"
        ]

        if analysis.related_assertion_names.any?
          lines << "      # Related Alloy assertions: #{analysis.related_assertion_names.join(', ')}"
        end
        if analysis.related_fact_names.any?
          lines << "      # Related Alloy facts: #{analysis.related_fact_names.join(', ')}"
        end
        if analysis.related_predicate_names.any?
          lines << "      # Related Alloy property predicates: #{analysis.related_predicate_names.join(', ')}"
        end
        if analysis.related_pattern_hints.any?
          lines << "      # Related pattern hints: #{analysis.related_pattern_hints.map(&:to_s).join(', ')}"
        end
        if analysis.derived_verify_hints.any?
          lines << "      # Derived verify hints: #{analysis.derived_verify_hints.map(&:to_s).join(', ')}"
        end
        lines.concat(guard_failure_context_lines(analysis))
        lines << "      # Suggested verify order:"
        lines << "      # 1. Command-specific postconditions"
        lines << "      # 2. Related Alloy assertions/facts"
        lines << "      # 3. Related property predicates"
        lines << "      return nil if #{support_module_name}.call_verify_override("
        lines << "        name,"
        lines << "        before_state: before_state,"
        lines << "        after_state: after_state,"
        lines << "        args: args,"
        lines << "        result: result,"
        lines << "        sut: sut,"
        lines << "        guard_failed: guard_failed,"
        lines << "        guard_failure_policy: policy"
        lines << "      )"
        lines.concat(guard_failure_verify_lines(analysis))
        lines.concat(default_observed_state_verify_lines(analysis))

        unless collection_like_state?(analysis)
          lines << "      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks"
          lines << "      # Inferred state target: #{state_target_label(analysis)}"
          lines.concat(derived_verify_comment_lines(analysis))
          lines.concat(scalar_verify_body(analysis))
          lines << "      [sut, args] && nil"
          lines << "    end"
          return lines
        end

        lines << "      # Inferred collection target: #{state_target_label(analysis)}"
        lines << "      before_items = #{collection_state_expr('before_state', analysis)}"
        lines << "      after_items = #{collection_state_expr('after_state', analysis)}"
        if (before_capacity_expr = capacity_state_expr('before_state', analysis))
          lines << "      before_capacity = #{before_capacity_expr}"
        end
        lines.concat(derived_verify_comment_lines(analysis))
        lines.concat(collection_verify_body(analysis, behavior))
        lines << "      [sut, args] && nil"
        lines << "    end"
        lines
      end

      private

      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs return: Array[String]
      def guard_failure_context_lines(analysis)
        if guard_supportable?(analysis) && analysis.derived_verify_hints.include?(:check_guard_failure_semantics)
          [
            "      policy = #{support_module_name}.guard_failure_policy(name)",
            "      guard_failed = policy && !guard_satisfied?(before_state, args)"
          ]
        else
          [
            "      policy = #{support_module_name}.guard_failure_policy(name)",
            "      guard_failed = false"
          ]
        end
      end

      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs return: Array[String]
      def guard_failure_verify_lines(analysis)
        return [] unless guard_supportable?(analysis) && analysis.derived_verify_hints.include?(:check_guard_failure_semantics)

        [
          "      raise result if result.is_a?(StandardError) && !guard_failed",
          "      if guard_failed",
          "        observed = #{support_module_name}.observed_state(sut)",
          "        case policy",
          "        when :no_op",
          "          raise \"Expected unchanged model state on guard failure\" unless after_state == before_state",
          "          raise \"Expected unchanged observed state on guard failure\" if !observed.nil? && observed != #{observed_state_expected_expr('after_state', analysis)}",
          "        when :raise",
          "          raise \"Expected guard failure to surface as an exception\" unless result.is_a?(StandardError)",
          "          raise \"Expected unchanged model state on guard failure\" unless after_state == before_state",
          "          raise \"Expected unchanged observed state on guard failure\" if !observed.nil? && observed != #{observed_state_expected_expr('after_state', analysis)}",
          "        when :custom",
          "          raise \"guard_failure_policy :custom requires verify_override to assert invalid-path semantics\"",
          "        else",
          "          raise \"Unsupported guard_failure_policy: \#{policy.inspect}\"",
          "        end",
          "        return nil",
          "      end"
        ]
      end

      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs return: Array[String]
      def default_observed_state_verify_lines(analysis)
        [
          "      observed = #{support_module_name}.observed_state(sut)",
          "      if !observed.nil?",
          "        expected_observed_state = #{observed_state_expected_expr('after_state', analysis)}",
          "        raise \"Expected observed state to match model\" unless observed == expected_observed_state",
          "      end"
        ]
      end

      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs behavior: Symbol
      # @rbs return: Array[String]
      def collection_verify_body(analysis, behavior)
        lines = [] #: Array[String]
        if analysis.derived_verify_hints.include?(:respect_non_empty_guard) && [:pop, :dequeue].include?(behavior)
          lines << "      raise \"Expected non-empty state before removal\" if before_items.empty?"
        end
        if analysis.derived_verify_hints.include?(:respect_capacity_guard) && behavior == :append && capacity_state_expr('before_state', analysis)
          lines << "      raise \"Expected available capacity before append\" unless before_items.length < before_capacity"
        end
        if analysis.derived_verify_hints.include?(:check_empty_semantics) && analysis.state_update_shape == :preserve_size
          lines << "      raise \"Expected empty-state semantics to stay aligned\" unless after_items.empty? == before_items.empty?"
        end
        lines << "      raise \"Expected size to stay the same\" unless after_items.length == before_items.length" if analysis.state_update_shape == :preserve_size
        lines.concat(collection_projection_verify_lines(analysis)) if analysis.state_update_shape == :preserve_size

        case behavior
        when :append
          lines << "      expected_size = before_items.length + 1"
          lines << "      raise \"Expected size to increase by 1\" unless after_items.length == expected_size"
          lines.concat(collection_projection_verify_lines(analysis))
          if analysis.derived_verify_hints.include?(:check_membership_semantics)
            lines << "      raise \"Expected appended argument to be present in model state\" unless after_items.include?(args)"
          end
          if analysis.derived_verify_hints.include?(:check_ordering_semantics)
            lines << "      raise \"Expected appended argument to become the newest element\" unless after_items.last == args"
          end
          if roundtrip_restore_after_append?(analysis)
            lines << "      restored_state = #{collection_state_update_expr('after_state', analysis, 'after_items[0...-1]')}"
            lines << "      raise \"Expected append/remove-last roundtrip to restore the previous model state\" unless restored_state == before_state"
          end
        when :pop
          lines << "      expected = #{expected_result_expr_for(analysis, fallback: 'before_items.last')}"
          lines << "      raise \"Expected popped value to match model\" unless result == expected"
          lines << "      raise \"Expected size to decrease by 1\" unless after_items.length == before_items.length - 1"
          if roundtrip_restore_after_pop?(analysis)
            lines << "      restored_state = #{collection_state_update_expr('after_state', analysis, 'after_items + [result]')}"
            lines << "      raise \"Expected remove-last/append roundtrip to restore the previous model state\" unless restored_state == before_state"
          end
        when :dequeue
          lines << "      expected = #{expected_result_expr_for(analysis, fallback: 'before_items.first')}"
          lines << "      raise \"Expected dequeued value to match model\" unless result == expected"
          lines << "      raise \"Expected size to decrease by 1\" unless after_items.length == before_items.length - 1"
        else
          lines << "      # TODO: add concrete collection checks for #{analysis.predicate_name}"
        end

        lines
      end

      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs return: Array[String]
      def scalar_verify_body(analysis)
        if structured_scalar_state?(analysis) && scalar_field_updates_for(analysis).length > 1
          return multi_scalar_verify_body(analysis)
        end

        lines =
          case analysis.state_update_shape
          when :increment
            if analysis.rhs_source_kind == :arg
              [
                "      delta = #{support_module_name}.scalar_model_arg(name, args)",
                "      before_value = #{scalar_state_expr('before_state', analysis)}",
                "      after_value = #{scalar_state_expr('after_state', analysis)}",
                "      raise \"Expected incremented value for #{state_target_label(analysis)}\" unless after_value == before_value + delta"
              ]
            elsif scalar_unit_delta?(analysis)
              [
                "      before_value = #{scalar_state_expr('before_state', analysis)}",
                "      after_value = #{scalar_state_expr('after_state', analysis)}",
                "      raise \"Expected incremented value for #{state_target_label(analysis)}\" unless after_value == before_value + 1"
              ]
            else
              [
                "      # TODO: verify incremented value for #{state_target_label(analysis)}",
                "      # Example shape: after_state should reflect a monotonic +1 style update"
              ]
            end
          when :decrement
            if analysis.rhs_source_kind == :arg
              lines = [
                "      delta = #{support_module_name}.scalar_model_arg(name, args)",
                "      before_value = #{scalar_state_expr('before_state', analysis)}",
                "      after_value = #{scalar_state_expr('after_state', analysis)}",
                "      raise \"Expected decremented value for #{state_target_label(analysis)}\" unless after_value == before_value - delta"
              ]
              if decrement_arg_bound_guard?(analysis)
                lines.insert(1, "      raise \"Expected sufficient scalar state before decrement\" unless delta <= #{guard_state_expr('before_state', analysis)}")
              end
              lines
            elsif scalar_unit_delta?(analysis)
              [
                "      before_value = #{scalar_state_expr('before_state', analysis)}",
                "      after_value = #{scalar_state_expr('after_state', analysis)}",
                "      raise \"Expected decremented value for #{state_target_label(analysis)}\" unless after_value == before_value - 1"
              ]
            else
              [
                "      # TODO: verify decremented value for #{state_target_label(analysis)}",
                "      # Example shape: after_state should reflect a monotonic -1 style update"
              ]
            end
          when :replace_with_arg
            lines = [
              "      expected = #{support_module_name}.scalar_model_arg(name, args)",
              "      raise \"Expected replaced value for #{state_target_label(analysis)}\" unless #{scalar_state_expr('after_state', analysis)} == expected"
            ]
            if replace_arg_bound_guard?(analysis)
              lines.insert(1, "      raise \"Expected bounded scalar argument for #{state_target_label(analysis)}\" unless expected <= #{guard_state_expr('before_state', analysis)}")
            end
            lines
          when :replace_constant
            constant_expr = scalar_constant_expr(analysis)
            if constant_expr
              [
                "      expected = #{constant_expr}",
                "      raise \"Expected replaced value for #{state_target_label(analysis)}\" unless #{scalar_state_expr('after_state', analysis)} == expected"
              ]
            else
              [
                "      # TODO: verify replaced constant value for #{state_target_label(analysis)}",
                "      # Example shape: compare the inferred target against a known reset/bounded constant"
              ]
            end
          when :replace_value
            source_expr = scalar_replace_source_expr('before_state', analysis)
            if source_expr
              [
                "      expected = #{source_expr}",
                "      raise \"Expected replaced value for #{state_target_label(analysis)}\" unless #{scalar_state_expr('after_state', analysis)} == expected"
              ]
            else
              [
                "      # TODO: verify replaced value for #{state_target_label(analysis)}",
                "      # Example shape: compare the inferred target against args/result"
              ]
            end
          when :preserve_value
            [
              "      raise \"Expected preserved value for #{state_target_label(analysis)}\" unless #{scalar_state_expr('after_state', analysis)} == #{scalar_state_expr('before_state', analysis)}",
              "      # Example shape: replace this equality check with a narrower field-level assertion if needed"
            ]
          else
            [
              "      # TODO: #{scalar_verify_guidance(analysis)}"
            ]
          end

        if numeric_scalar_state?(analysis) && analysis.derived_verify_hints.include?(:check_non_negative_scalar_state)
          lines << "      raise \"Expected non-negative value for #{state_target_label(analysis)}\" unless #{scalar_state_expr('after_state', analysis)} >= 0"
        end

        lines
      end

      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs return: Array[String]
      def multi_scalar_verify_body(analysis)
        updates = scalar_field_updates_for(analysis)
        lines = [] #: Array[String]
        lines << "      delta = #{support_module_name}.scalar_model_arg(name, args)" if updates.any? { |update| update[:rhs_source_kind] == :arg }
        updates.each do |update|
          lines << "      before_#{update[:field]} = before_state[:#{update[:field]}]"
          lines << "      after_#{update[:field]} = after_state[:#{update[:field]}]"
          case update[:update_shape]
          when :increment
            increment_expr = update[:rhs_source_kind] == :arg ? "before_#{update[:field]} + delta" : "before_#{update[:field]} + 1"
            lines << "      raise \"Expected incremented value for #{analysis.state_type}##{update[:field]}\" unless after_#{update[:field]} == #{increment_expr}"
          when :decrement
            if update[:rhs_source_kind] == :arg && update[:field] == analysis.state_field && decrement_arg_bound_guard?(analysis)
              lines << "      raise \"Expected sufficient scalar state before decrement\" unless delta <= #{guard_state_expr('before_state', analysis)}"
            end
            decrement_expr = update[:rhs_source_kind] == :arg ? "before_#{update[:field]} - delta" : "before_#{update[:field]} - 1"
            lines << "      raise \"Expected decremented value for #{analysis.state_type}##{update[:field]}\" unless after_#{update[:field]} == #{decrement_expr}"
          when :replace_value
            source_expr = scalar_field_update_expr('before_state', update)
            lines << "      expected_#{update[:field]} = #{source_expr}" if source_expr
            lines << "      raise \"Expected replaced value for #{analysis.state_type}##{update[:field]}\" unless after_#{update[:field]} == expected_#{update[:field]}" if source_expr
          when :replace_constant
            next unless update[:rhs_constant]

            lines << "      expected_#{update[:field]} = #{update[:rhs_constant]}"
            lines << "      raise \"Expected replaced value for #{analysis.state_type}##{update[:field]}\" unless after_#{update[:field]} == expected_#{update[:field]}"
          when :replace_with_arg
            lines << "      expected_#{update[:field]} = #{support_module_name}.scalar_model_arg(name, args)"
            if replace_arg_bound_guard?(analysis)
              lines << "      raise \"Expected bounded scalar argument for #{analysis.state_type}##{update[:field]}\" unless expected_#{update[:field]} <= #{guard_state_expr('before_state', analysis)}"
            end
            lines << "      raise \"Expected replaced value for #{analysis.state_type}##{update[:field]}\" unless after_#{update[:field]} == expected_#{update[:field]}"
          when :preserve_value
            lines << "      raise \"Expected preserved value for #{analysis.state_type}##{update[:field]}\" unless after_#{update[:field]} == before_#{update[:field]}"
          end
          if numeric_scalar_field_name?(analysis, update[:field]) && analysis.derived_verify_hints.include?(:check_non_negative_scalar_state)
            lines << "      raise \"Expected non-negative value for #{analysis.state_type}##{update[:field]}\" unless after_#{update[:field]} >= 0"
          end
        end

        if transfer_like_scalar_updates?(updates)
          before_total = updates.map { |update| "before_#{update[:field]}" }.join(' + ')
          after_total = updates.map { |update| "after_#{update[:field]}" }.join(' + ')
          lines << "      raise \"Expected total scalar value to stay the same\" unless #{after_total} == #{before_total}"
        end

        lines
      end

      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs return: Array[String]
      def derived_verify_comment_lines(analysis)
        lines = [] #: Array[String]
        if analysis.derived_verify_hints.include?(:respect_non_empty_guard)
          lines << "      # Derived from related assertions/facts: respect the non-empty guard before removal-style checks"
        end
        if analysis.derived_verify_hints.include?(:respect_capacity_guard)
          lines << "      # Derived from related assertions/facts: respect capacity/fullness guards before append-style checks"
        end
        if analysis.derived_verify_hints.include?(:check_empty_semantics)
          lines << "      # Derived from related property patterns: verify empty-state semantics for the inferred target"
        end
        if analysis.derived_verify_hints.include?(:check_ordering_semantics)
          lines << "      # Derived from related property patterns: verify ordering semantics (for example LIFO/FIFO) where relevant"
        end
        if analysis.derived_verify_hints.include?(:check_roundtrip_pairing)
          lines << "      # Derived from related property patterns: verify paired-command roundtrip behavior against sibling commands"
        end
        if analysis.derived_verify_hints.include?(:check_size_semantics)
          lines << "      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts"
        end
        if analysis.derived_verify_hints.include?(:check_membership_semantics)
          lines << "      # Derived from related property patterns: verify membership semantics for appended/removed elements where safe"
        end
        if analysis.derived_verify_hints.include?(:check_projection_semantics)
          lines << "      # Derived from collection/scalar updates: verify append-only projection semantics against companion scalar fields"
        end
        if analysis.derived_verify_hints.include?(:check_non_negative_scalar_state)
          lines << "      # Derived from related assertions/facts: keep non-negative scalar invariants aligned with the model state"
        end
        if analysis.derived_verify_hints.include?(:check_guard_failure_semantics)
          lines << "      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged"
        end

        lines
      end

      # @rbs analysis: StatefulPredicateAnalysis?
      # @rbs return: String
      def scalar_verify_guidance(analysis)
        return 'verify scalar/domain-specific postconditions' unless analysis

        case analysis.state_update_shape
        when :replace_with_arg, :replace_value
          "verify replaced value for #{state_target_label(analysis)}"
        when :increment
          "verify incremented value for #{state_target_label(analysis)}"
        when :decrement
          "verify decremented value for #{state_target_label(analysis)}"
        when :preserve_value
          "verify preserved value for #{state_target_label(analysis)}"
        else
          "verify scalar/domain-specific postconditions for #{state_target_label(analysis)}"
        end
      end

      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs return: Array[String]
      def collection_projection_verify_lines(analysis)
        projection_plan = projection_plan_for(analysis)
        updates = projection_plan.updates
        return [] if updates.empty?

        lines = [] #: Array[String]
        lines << "      delta = #{support_module_name}.scalar_model_arg(name, args)" if projection_plan.needs_delta
        if analysis.derived_verify_hints.include?(:check_projection_semantics)
          lines << "      raise \"Expected appended projection entry to match the model delta\" unless after_items.last == #{projection_plan.append_item_expr}"
        end
        updates.each do |update|
          lines << "      before_#{update[:field]} = before_state[:#{update[:field]}]"
          lines << "      after_#{update[:field]} = after_state[:#{update[:field]}]"
          case update[:update_shape]
          when :increment
            increment_expr = update[:rhs_source_kind] == :arg ? "before_#{update[:field]} + delta" : "before_#{update[:field]} + 1"
            lines << "      raise \"Expected incremented value for #{analysis.state_type}##{update[:field]}\" unless after_#{update[:field]} == #{increment_expr}"
          when :decrement
            decrement_expr = update[:rhs_source_kind] == :arg ? "before_#{update[:field]} - delta" : "before_#{update[:field]} - 1"
            lines << "      raise \"Expected decremented value for #{analysis.state_type}##{update[:field]}\" unless after_#{update[:field]} == #{decrement_expr}"
          when :replace_with_arg
            lines << "      expected_#{update[:field]} = #{support_module_name}.scalar_model_arg(name, args)"
            lines << "      raise \"Expected replaced value for #{analysis.state_type}##{update[:field]}\" unless after_#{update[:field]} == expected_#{update[:field]}"
          when :replace_constant
            next unless update[:rhs_constant]

            lines << "      expected_#{update[:field]} = #{update[:rhs_constant]}"
            lines << "      raise \"Expected replaced value for #{analysis.state_type}##{update[:field]}\" unless after_#{update[:field]} == expected_#{update[:field]}"
          when :replace_value
            source_expr = scalar_field_update_expr('before_state', update)
            lines << "      expected_#{update[:field]} = #{source_expr}"
            lines << "      raise \"Expected replaced value for #{analysis.state_type}##{update[:field]}\" unless after_#{update[:field]} == expected_#{update[:field]}"
          when :preserve_value
            lines << "      raise \"Expected preserved value for #{analysis.state_type}##{update[:field]}\" unless after_#{update[:field]} == before_#{update[:field]}"
          end
        end
        lines
      end

      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs return: bool
      def roundtrip_restore_after_append?(analysis)
        analysis.derived_verify_hints.include?(:check_roundtrip_pairing) &&
          sibling_command_behaviors_for(analysis).include?(:pop)
      end

      # @rbs analysis: StatefulPredicateAnalysis
      # @rbs return: bool
      def roundtrip_restore_after_pop?(analysis)
        analysis.derived_verify_hints.include?(:check_roundtrip_pairing) &&
          analysis.state_update_shape == :remove_last &&
          sibling_command_behaviors_for(analysis).include?(:append)
      end

      # @rbs updates: Array[Hash[Symbol, untyped]]
      # @rbs return: bool
      def transfer_like_scalar_updates?(updates)
        increments = updates.count { |update| update[:update_shape] == :increment }
        decrements = updates.count { |update| update[:update_shape] == :decrement }
        increments == 1 && decrements == 1 &&
          updates.all? { |update| [:arg, :unknown].include?(update[:rhs_source_kind]) }
      end

      # @rbs method_name: Symbol
      # @rbs args: *untyped
      # @rbs kwargs: **untyped
      # @rbs return: untyped
      def call(method_name, *args, **kwargs)
        @generator.__send__(method_name, *args, **kwargs)
      end

      def support_module_name = call(:support_module_name)
      def guard_supportable?(analysis) = call(:guard_supportable?, analysis)
      def collection_like_state?(analysis) = call(:collection_like_state?, analysis)
      def structured_collection_state?(analysis) = call(:structured_collection_state?, analysis)
      def structured_scalar_state?(analysis) = call(:structured_scalar_state?, analysis)
      def collection_state_expr(state_var, analysis) = call(:collection_state_expr, state_var, analysis)
      def capacity_state_expr(state_var, analysis) = call(:capacity_state_expr, state_var, analysis)
      def state_target_label(analysis) = call(:state_target_label, analysis)
      def scalar_state_expr(state_var, analysis) = call(:scalar_state_expr, state_var, analysis)
      def collection_state_update_expr(state_var, analysis, expr) = call(:collection_state_update_expr, state_var, analysis, expr)
      def expected_result_expr_for(analysis, fallback:) = call(:expected_result_expr_for, analysis, fallback: fallback)
      def numeric_scalar_state?(analysis) = call(:numeric_scalar_state?, analysis)
      def numeric_scalar_field_name?(analysis, field_name) = call(:numeric_scalar_field_name?, analysis, field_name)
      def scalar_field_updates_for(analysis) = call(:scalar_field_updates_for, analysis)
      def scalar_replace_source_expr(state_var, analysis) = call(:scalar_replace_source_expr, state_var, analysis)
      def scalar_field_update_expr(state_var, update) = call(:scalar_field_update_expr, state_var, update)
      def scalar_constant_expr(analysis) = call(:scalar_constant_expr, analysis)
      def scalar_unit_delta?(analysis) = call(:scalar_unit_delta?, analysis)
      def decrement_arg_bound_guard?(analysis) = call(:decrement_arg_bound_guard?, analysis)
      def replace_arg_bound_guard?(analysis) = call(:replace_arg_bound_guard?, analysis)
      def guard_state_expr(state_var, analysis) = call(:guard_state_expr, state_var, analysis)
      def observed_state_expected_expr(state_var, analysis) = call(:observed_state_expected_expr, state_var, analysis)
      def sibling_command_behaviors_for(analysis) = call(:sibling_command_behaviors_for, analysis)
      def collection_projection_updates_for(analysis) = call(:collection_projection_updates_for, analysis)
      def projection_plan_for(analysis) = call(:projection_plan_for, analysis)
    end
  end
end
