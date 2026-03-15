# frozen_string_literal: true

# rbs_inline: enabled

module SpecToPbt
  # Generates a stateful PBT scaffold that targets `Pbt.stateful`.
  class StatefulGenerator
    PRIMITIVE_TYPES = ["Int", "String"].freeze #: Array[String]
    EXCLUDED_COMMAND_PATTERNS = [:roundtrip, :ordering, :invariant, :idempotent, :empty].freeze #: Array[Symbol]

    # @rbs spec: untyped
    # @rbs return: void
    def initialize(spec)
      @spec = Core::Coercion.call(spec) #: Core::SpecDocument
      @type_inferrer = TypeInferrer.new(@spec) #: TypeInferrer
      @predicate_analyzer = StatefulPredicateAnalyzer.new(@spec) #: StatefulPredicateAnalyzer
      @state_shape_inspector = StateShapeInspector.new(self)
    end

    # @rbs return: String
    def generate
      lines = [] #: Array[String]
      lines << "# frozen_string_literal: true"
      lines << ""
      lines << 'require "pbt"'
      lines << 'require "rspec"'
      lines << %(require_relative "#{module_name}_impl")
      lines << %(require_relative "#{config_file_basename}" if File.exist?(File.expand_path("#{config_file_basename}.rb", __dir__)))
      lines << ""
      lines << %(if File.exist?(File.expand_path("#{config_file_basename}.rb", __dir__)) && !defined?(::#{config_constant_name}))
      lines << %(  raise "Expected #{config_constant_name} to be defined in #{config_file_basename}.rb")
      lines << "end"
      lines << ""
      lines << "unless Pbt.respond_to?(:stateful)"
      lines << "  loaded_pbt_version = defined?(Gem.loaded_specs) ? Gem.loaded_specs[\"pbt\"]&.version&.to_s : nil"
      lines << "  detail = loaded_pbt_version ? \"loaded pbt \#{loaded_pbt_version}\" : \"loaded pbt version unknown\""
      lines << %(  raise "Expected pbt >= #{SpecToPbt::PBT_STATEFUL_MIN_VERSION} with Pbt.stateful (\#{detail}). Install a compatible pbt release before running this scaffold.")
      lines << "end"
      lines << ""
      lines << %(RSpec.describe "#{module_name} (stateful scaffold)" do)
      lines << "  # Regeneration-safe customization:"
      lines << "  # - edit #{config_file_basename}.rb for SUT wiring and durable API mapping"
      lines << "  # - edit #{module_name}_impl.rb for implementation behavior"
      lines << "  # - edit this scaffold only for one-off refinements when needed"
      lines << ""
      lines.concat(config_support_lines)
      lines << ""
      lines << "  it \"wires a stateful PBT scaffold (customize before enabling)\" do"
      lines << '    unless ENV["ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD"] == "1"'
      lines << '      skip "Set ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 after customizing the generated scaffold"'
      lines << "    end"
      lines << ""
      lines << "    Pbt.assert(worker: :none, num_runs: 5, seed: 1) do"
      lines << "      Pbt.stateful("
      lines << "        model: #{model_class_name}.new,"
      lines << "        sut: -> { #{support_module_name}.sut_factory(-> { #{sut_factory_code} }).call },"
      lines << "        max_steps: 20"
      lines << "      )"
      lines << "    end"
      lines << "  end"
      lines << ""
      lines << "  class #{model_class_name}"
      lines << "    def initialize"
      lines << "      @commands = ["
      command_class_names.each_with_index do |class_name, index|
        suffix = index == command_class_names.length - 1 ? "" : ","
        lines << "        #{class_name}.new#{suffix}"
      end
      lines << "      ]"
      lines << "    end"
      lines << ""
      lines << "    def initial_state"
      lines << "      default_state = #{initial_state_code}"
      lines << "      #{support_module_name}.initial_state(default_state)"
      lines << "    end"
      lines << ""
      lines << "    def commands(_state)"
      lines << "      @commands"
      lines << "    end"
      lines << "  end"
      lines << ""

      if selected_command_predicates.empty?
        lines.concat(generated_command_fallback_lines)
        lines << ""
      else
        selected_command_predicates.each do |predicate|
          lines.concat(command_class_lines(predicate))
          lines << ""
        end
      end

      lines << "end"
      lines.join("\n")
    end

    # @rbs return: String
    def generate_config
      ConfigRenderer.new(self).render
    end

    private

    # @rbs return: String
    def module_name
      @spec.name || "operation"
    end

    # @rbs return: String
    def model_class_name
      "#{camelize(module_name)}Model"
    end

    # @rbs return: String
    def sut_factory_code
      "#{camelize(module_name)}Impl.new"
    end

    # @rbs return: String
    def config_constant_name
      StatefulConfigName.for(module_name)[:constant_name]
    end

    # @rbs return: String
    def config_file_basename
      StatefulConfigName.for(module_name)[:file_basename]
    end

    # @rbs return: String
    def support_module_name
      "#{camelize(module_name)}PbtSupport"
    end

    # @rbs return: Array[Core::Entity]
    def selected_command_predicates
      @selected_command_predicates ||= @spec.properties.select { |predicate| command_like_predicate?(predicate) } #: Array[Core::Entity]
    end

    # @rbs return: Array[String]
    def command_class_names
      names = selected_command_predicates.map { |predicate| "#{camelize(predicate.name)}Command" }
      names.empty? ? ["GeneratedCommand"] : names
    end

    # @rbs return: String
    def initial_state_code
      InitialStateInferencer.new(self).scaffold_code
    end

    # @rbs return: String
    def initial_state_config_example
      InitialStateInferencer.new(self).config_example
    end

    # @rbs predicate: Core::Entity
    # @rbs return: bool
    def command_like_predicate?(predicate)
      analysis = predicate_analysis(predicate)
      patterns = PropertyPattern.detect(predicate.name, predicate.normalized_text)
      return false if (patterns & EXCLUDED_COMMAND_PATTERNS).any?
      return false if property_like_name?(predicate.name)
      return false if analysis.command_confidence == :low

      [:append, :pop, :dequeue, :size_no_change].include?(analysis.transition_kind) ||
        analysis.state_update_shape != :unknown ||
        analysis.guard_kind != :none
    end

    # @rbs predicate: Core::Entity
    # @rbs return: Array[Core::Parameter]
    def argument_params(predicate)
      predicate_analysis(predicate).argument_params
    end

    # @rbs predicate: Core::Entity
    # @rbs return: String
    def arguments_code(predicate)
      params = argument_params(predicate)
      return "Pbt.nil" if params.empty?

      arbitraries = params.map { |param| arbitrary_code_for(param.type) }
      return arbitraries.first if arbitraries.size == 1

      "Pbt.tuple(#{arbitraries.join(', ')})"
    end

    # @rbs predicate: Core::Entity
    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: Array[String]
    def arguments_lines(predicate, analysis)
      if state_aware_scalar_arg_generation?(analysis)
        [
          "    def arguments(state)",
          "      overridden = #{support_module_name}.call_arguments_override(name, state)",
          "      return overridden unless overridden.equal?(#{support_module_name}::ARGUMENTS_OVERRIDE_UNSET)",
          "      Pbt.integer(min: 1, max: #{scalar_argument_domain_expr('state', analysis)})",
          "    end"
        ]
      else
        [
          "    def arguments",
          "      overridden = #{support_module_name}.call_arguments_override(name)",
          "      return overridden unless overridden.equal?(#{support_module_name}::ARGUMENTS_OVERRIDE_UNSET)",
          "      #{arguments_code(predicate)}",
          "    end"
        ]
      end
    end

    # @rbs type_name: String
    # @rbs return: String
    def arbitrary_code_for(type_name)
      code = @type_inferrer.generator_for(type_name)
      return code if PRIMITIVE_TYPES.include?(type_name)

      "#{code} # placeholder for #{type_name}"
    end

    # @rbs predicate: Core::Entity
    # @rbs return: Symbol
    def command_behavior(predicate)
      analysis = predicate_analysis(predicate)
      return :append if [:append, :append_like].include?(analysis.state_update_shape) || analysis.transition_kind == :append
      return :dequeue if analysis.state_update_shape == :remove_first || analysis.transition_kind == :dequeue
      return :pop if analysis.state_update_shape == :remove_last || analysis.transition_kind == :pop
      return :size_no_change if analysis.state_update_shape == :preserve_size || analysis.transition_kind == :size_no_change

      :unknown
    end

    # @rbs predicate: Core::Entity
    # @rbs return: String
    def method_name_for(predicate)
      underscore(predicate.name)
    end

    # @rbs predicate: Core::Entity
    # @rbs return: Array[String]
    def command_class_lines(predicate)
      plan = build_command_plan(predicate)
      analysis = plan.analysis

      [
        "  class #{plan.class_name}",
        *command_confidence_hint_lines(analysis),
        "    def name",
        "      :#{plan.method_name}",
        "    end",
        "",
        *arguments_lines(predicate, analysis),
        "",
        *applicable_lines(plan),
        *guard_helper_separator_lines(plan),
        *guard_helper_lines(plan),
        "",
        *next_state_lines(plan),
        "",
        *run_lines(plan.method_name),
        "",
        *verify_lines(plan),
        "  end"
      ]
    end

    # @rbs predicate: Core::Entity
    # @rbs return: CommandPlan
    def build_command_plan(predicate)
      analysis = predicate_analysis(predicate)
      method_name = method_name_for(predicate)
      behavior = command_behavior(predicate)
      state_shape =
        if projection_collection_state?(analysis)
          :projection_collection
        elsif structured_collection_state?(analysis)
          :structured_collection
        elsif collection_like_state?(analysis)
          :collection
        elsif structured_scalar_state?(analysis)
          :structured_scalar
        else
          :scalar
        end
      CommandPlan.new(
        predicate: predicate,
        analysis: analysis,
        behavior: behavior,
        method_name: method_name,
        class_name: "#{camelize(predicate.name)}Command",
        body_preview: predicate.normalized_text,
        arg_aware_applicability: arg_aware_applicability?(analysis),
        guard_supportable: guard_supportable?(analysis),
        state_shape: state_shape,
        next_state_mode: (state_shape == :scalar || state_shape == :structured_scalar ? :scalar : behavior)
      )
    end

    # @rbs return: Array[String]
    def generated_command_fallback_lines
      [
        "  class GeneratedCommand",
        "    def name",
        "      :generated_command",
        "    end",
        "",
        "    def arguments",
        "      Pbt.nil",
        "    end",
        "",
        "    def applicable?(_state)",
        "      true",
        "    end",
        "",
        "    def next_state(state, _args)",
        "      state",
        "    end",
        "",
        "    def run!(_sut, _args)",
        "      nil",
        "    end",
        "",
        "    def verify!(before_state:, after_state:, args:, result:, sut:)",
        "      # TODO: no command-like predicates were detected; replace this placeholder",
        "      nil",
        "    end",
        "  end"
      ]
    end

    # @rbs plan: CommandPlan
    # @rbs return: Array[String]
    def applicable_lines(plan)
      analysis = plan.analysis
      method_name = plan.method_name
      state_items = collection_state_expr("state", analysis)
      if plan.arg_aware_applicability?
        lines = [
          "    def applicable?(state, args)",
          "      override = #{support_module_name}.applicable_override(name)",
          "      return #{support_module_name}.call_applicable_override(override, state, args) if override"
        ]
        if plan.guard_supportable?
          lines << "      return true if #{support_module_name}.guard_failure_policy(name)"
          lines << "      guard_satisfied?(state, args)"
        else
          lines << "      true # TODO: unsupported arg-aware guard shape; keep this config-owned via applicable_override (and next_state_override / verify_override if invalid calls have domain-specific semantics)"
        end
        lines << "    end"
        return lines
      end

      lines = [
        "    def applicable?(state)",
        "      override = #{support_module_name}.applicable_override(name)",
        "      return #{support_module_name}.call_applicable_override(override, state, nil) if override"
      ]
      if plan.guard_supportable?
        lines << "      return true if #{support_module_name}.guard_failure_policy(name)"
        lines << "      guard_satisfied?(state)"
      elsif analysis.guard_kind != :none
        lines << "      true # TODO: unsupported guard shape; keep this config-owned via applicable_override or a custom invalid-path contract"
      else
        lines << "      true"
      end
      lines << "    end"
      lines
    end

    # @rbs plan: CommandPlan
    # @rbs return: Array[String]
    def guard_helper_separator_lines(plan)
      plan.guard_supportable? ? [""] : []
    end

    # @rbs plan: CommandPlan
    # @rbs return: Array[String]
    def guard_helper_lines(plan)
      analysis = plan.analysis
      method_name = plan.method_name
      return [] unless plan.guard_supportable?

      lines = [
        "    def guard_satisfied?(#{plan.guard_signature})"
      ]

      if bounded_scalar_arg_generation?(analysis)
        lines << "      delta = #{support_module_name}.scalar_model_arg(name, args)"
        lines << "      current_value = #{guard_state_expr('state', analysis)}"
        lines << "      delta.is_a?(Numeric) && delta.positive? && delta <= current_value"
      elsif collection_like_state?(analysis) && analysis.guard_kind == :non_empty
        if analysis.guard_field && analysis.guard_field != analysis.state_field
          lines << "      #{guard_state_expr('state', analysis)} > 0 # inferred structured collection/scalar guard for #{method_name}"
        else
          lines << "      !#{collection_state_expr('state', analysis)}.empty? # inferred precondition for #{method_name}"
        end
      elsif collection_like_state?(analysis) && analysis.guard_kind == :below_capacity
        capacity_expr = capacity_state_expr("state", analysis)
        if capacity_expr
          lines << "      #{collection_state_expr('state', analysis)}.length < #{capacity_expr} # inferred capacity/fullness guard for #{method_name}"
        else
          lines << "      true # TODO: inferred capacity/fullness guard for #{method_name}; use applicable_override or enrich the model state"
        end
      elsif collection_like_state?(analysis) && analysis.guard_kind == :state_equals_constant && !analysis.guard_constant.nil?
        lines << "      #{guard_state_expr('state', analysis)} == #{analysis.guard_constant} # inferred structured collection/status precondition for #{method_name}"
      elsif !collection_like_state?(analysis) && analysis.guard_kind == :state_equals_constant && !analysis.guard_constant.nil?
        lines << "      #{guard_state_expr('state', analysis)} == #{analysis.guard_constant} # inferred scalar lifecycle/status precondition for #{method_name}"
      elsif !collection_like_state?(analysis) && analysis.guard_kind == :non_empty
        lines << "      #{scalar_state_expr('state', analysis)} > 0 # inferred scalar precondition for #{method_name}"
      else
        lines << "      true"
      end

      lines << "    end"
      lines
    end

    # @rbs plan: CommandPlan
    # @rbs return: Array[String]
    def next_state_lines(plan)
      analysis = plan.analysis
      behavior = plan.behavior
      return scalar_next_state_lines(analysis) if plan.scalar_state?
      state_items = collection_state_expr("state", analysis)

      case plan.next_state_mode
      when :append
        collection_append_next_state_lines(analysis, state_items)
      when :pop
        [
          "    def next_state(state, args)",
          "      override = #{support_module_name}.next_state_override(name)",
          "      return #{support_module_name}.call_next_state_override(override, state, args) if override",
          *guard_failed_next_state_lines(analysis),
          "      # Inferred transition target: #{state_target_label(analysis)}",
          "      #{collection_state_update_expr('state', analysis, "#{state_items}[0...-1]")}"
        ]
      when :dequeue
        [
          "    def next_state(state, args)",
          "      override = #{support_module_name}.next_state_override(name)",
          "      return #{support_module_name}.call_next_state_override(override, state, args) if override",
          *guard_failed_next_state_lines(analysis),
          "      # Inferred transition target: #{state_target_label(analysis)}",
          "      #{collection_state_update_expr('state', analysis, "#{state_items}.drop(1)")}"
        ]
      when :size_no_change
        collection_size_no_change_next_state_lines(analysis, state_items)
      else
        generic_next_state_lines(plan)
      end + ["    end"]
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: Array[String]
    def scalar_next_state_lines(analysis)
      if structured_scalar_state?(analysis) && scalar_field_updates_for(analysis).length > 1
        return multi_scalar_next_state_lines(analysis)
      end

      guidance =
        case analysis.state_update_shape
        when :increment
          "increment #{state_target_label(analysis)} based on args/result"
        when :decrement
          "decrement #{state_target_label(analysis)} based on args/result"
        when :replace_with_arg
          "replace #{state_target_label(analysis)} using args"
        when :replace_constant
          "replace #{state_target_label(analysis)} using an inferred constant"
        when :replace_value
          "replace #{state_target_label(analysis)} using args/result"
        when :preserve_value
          "keep #{state_target_label(analysis)} stable unless other domain state changes"
        else
          scalar_update_guidance(analysis)
        end

      if analysis.state_update_shape == :increment && analysis.rhs_source_kind == :arg
        [
          "    def next_state(state, args)",
          "      override = #{support_module_name}.next_state_override(name)",
          "      return #{support_module_name}.call_next_state_override(override, state, args) if override",
          *guard_failed_next_state_lines(analysis),
          "      delta = #{support_module_name}.scalar_model_arg(name, args)",
          "      #{scalar_state_update_expr('state', analysis, "#{scalar_state_expr('state', analysis)} + delta")}",
          "    end"
        ]
      elsif analysis.state_update_shape == :decrement && analysis.rhs_source_kind == :arg
        [
          "    def next_state(state, args)",
          "      override = #{support_module_name}.next_state_override(name)",
          "      return #{support_module_name}.call_next_state_override(override, state, args) if override",
          *guard_failed_next_state_lines(analysis),
          "      delta = #{support_module_name}.scalar_model_arg(name, args)",
          "      #{scalar_state_update_expr('state', analysis, "#{scalar_state_expr('state', analysis)} - delta")}",
          "    end"
        ]
      elsif analysis.state_update_shape == :increment && scalar_unit_delta?(analysis)
        [
          "    def next_state(state, args)",
          "      override = #{support_module_name}.next_state_override(name)",
          "      return #{support_module_name}.call_next_state_override(override, state, args) if override",
          *guard_failed_next_state_lines(analysis),
          "      #{scalar_state_update_expr('state', analysis, "#{scalar_state_expr('state', analysis)} + 1")}",
          "    end"
        ]
      elsif analysis.state_update_shape == :decrement && scalar_unit_delta?(analysis)
        [
          "    def next_state(state, args)",
          "      override = #{support_module_name}.next_state_override(name)",
          "      return #{support_module_name}.call_next_state_override(override, state, args) if override",
          *guard_failed_next_state_lines(analysis),
          "      #{scalar_state_update_expr('state', analysis, "#{scalar_state_expr('state', analysis)} - 1")}",
          "    end"
        ]
      elsif analysis.state_update_shape == :replace_with_arg
        [
          "    def next_state(state, args)",
          "      override = #{support_module_name}.next_state_override(name)",
          "      return #{support_module_name}.call_next_state_override(override, state, args) if override",
          *guard_failed_next_state_lines(analysis),
          "      #{scalar_state_update_expr('state', analysis, "#{support_module_name}.scalar_model_arg(name, args)")}",
          "    end"
        ]
      elsif analysis.state_update_shape == :replace_constant && (constant_expr = scalar_constant_expr(analysis))
        [
          "    def next_state(state, args)",
          "      override = #{support_module_name}.next_state_override(name)",
          "      return #{support_module_name}.call_next_state_override(override, state, args) if override",
          *guard_failed_next_state_lines(analysis),
          "      #{scalar_state_update_expr('state', analysis, constant_expr)}",
          "    end"
        ]
      elsif analysis.state_update_shape == :replace_value && (source_expr = scalar_replace_source_expr("state", analysis))
        [
          "    def next_state(state, args)",
          "      override = #{support_module_name}.next_state_override(name)",
          "      return #{support_module_name}.call_next_state_override(override, state, args) if override",
          *guard_failed_next_state_lines(analysis),
          "      #{scalar_state_update_expr('state', analysis, source_expr)}",
          "    end"
        ]
      else
        [
          "    def next_state(state, args)",
          "      override = #{support_module_name}.next_state_override(name)",
          "      return #{support_module_name}.call_next_state_override(override, state, args) if override",
          *guard_failed_next_state_lines(analysis),
          "      state # TODO: #{guidance}",
          "    end"
        ]
      end
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: Array[String]
    def multi_scalar_next_state_lines(analysis)
      updates = scalar_field_updates_for(analysis)
      needs_args = updates.any? { |update| [:arg, :arg_field].include?(update[:rhs_source_kind]) }
      lines = ["    def next_state(state, args)"]
      lines << "      override = #{support_module_name}.next_state_override(name)"
      lines << "      return #{support_module_name}.call_next_state_override(override, state, args) if override"
      lines.concat(guard_failed_next_state_lines(analysis))
      lines << "      delta = #{support_module_name}.scalar_model_arg(name, args)" if updates.any? { |update| update[:rhs_source_kind] == :arg }
      pairs = updates.map { |update| "#{update[:field]}: #{scalar_field_update_expr('state', update)}" }
      lines << "      state.merge(#{pairs.join(', ')})"
      lines << "    end"
      lines
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs state_items: String
    # @rbs return: Array[String]
    def collection_append_next_state_lines(analysis, state_items)
      lines = [
        "    def next_state(state, args)",
        "      override = #{support_module_name}.next_state_override(name)",
        "      return #{support_module_name}.call_next_state_override(override, state, args) if override",
        *guard_failed_next_state_lines(analysis),
        "      # Inferred transition target: #{state_target_label(analysis)}"
      ]

      if projection_collection_state?(analysis)
        lines << "      delta = #{support_module_name}.scalar_model_arg(name, args)"
        pairs = ["#{analysis.state_field}: #{state_items} + [#{collection_append_item_expr(analysis)}]"]
        collection_projection_updates_for(analysis).each do |update|
          pairs << "#{update[:field]}: #{scalar_field_update_expr('state', update)}"
        end
        lines << "      state.merge(#{pairs.join(', ')})"
      else
        lines << "      #{collection_state_update_expr('state', analysis, "#{state_items} + [args]")}"
      end

      lines
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs state_items: String
    # @rbs return: Array[String]
    def collection_size_no_change_next_state_lines(analysis, state_items)
      lines = [
        "    def next_state(state, args)",
        "      override = #{support_module_name}.next_state_override(name)",
        "      return #{support_module_name}.call_next_state_override(override, state, args) if override",
        *guard_failed_next_state_lines(analysis),
        "      # Inferred transition target: #{state_target_label(analysis)}"
      ]

      updates = collection_projection_updates_for(analysis)
      if updates.empty?
        lines << "      #{collection_state_update_expr('state', analysis, state_items)} # TODO: preserve size while refining element/order changes"
      else
        pairs = ["#{analysis.state_field}: #{state_items}"]
        updates.each do |update|
          pairs << "#{update[:field]}: #{scalar_field_update_expr('state', update)}"
        end
        lines << "      state.merge(#{pairs.join(', ')})"
      end

      lines
    end

    # @rbs plan: CommandPlan
    # @rbs return: Array[String]
    def generic_next_state_lines(plan)
      analysis = plan.analysis
      if plan.scalar_state?
        scalar_next_state_lines(analysis)
      else
        [
          "    def next_state(state, _args)",
          "      state # TODO: model transition (analyzer could not infer a collection-safe update)",
          "    end"
        ]
      end
    end

    # @rbs method_name: String
    # @rbs return: Array[String]
    def run_lines(method_name)
      [
        "    def run!(sut, args)",
        "      #{support_module_name}.before_run_hook&.call(sut)",
        "      payload = #{support_module_name}.adapt_args(name, args)",
        "      method_name = #{support_module_name}.resolve_method_name(name, :#{method_name})",
        "      result = begin",
        "        if payload.nil?",
        "          sut.public_send(method_name)",
        "        elsif payload.is_a?(Array)",
        "          sut.public_send(method_name, *payload)",
        "        else",
        "          sut.public_send(method_name, payload)",
        "        end",
        "      rescue StandardError => error",
        "        raise unless [:raise, :custom].include?(#{support_module_name}.guard_failure_policy(name))",
        "        error",
        "      end",
        "      adapted_result = #{support_module_name}.adapt_result(name, result)",
        "      #{support_module_name}.after_run_hook&.call(sut, adapted_result)",
        "      adapted_result",
        "    end"
      ]
    end

# @rbs plan: CommandPlan
# @rbs return: Array[String]
def verify_lines(plan)
  VerifyRenderer.new(self).render_lines(plan)
end
    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: Array[String]
    def guard_failed_next_state_lines(analysis)
      return [] unless guard_supportable?(analysis)

      ["      return state if #{support_module_name}.guard_failure_policy(name) && !guard_satisfied?(state, args)"]
    end

# @rbs analysis: StatefulPredicateAnalysis
# @rbs return: Array[Hash[Symbol, untyped]]
def scalar_field_updates_for(analysis)
      updates = analysis.state_field_updates || []
      return updates unless updates.empty?
      return [] unless analysis.state_field

      [{
        field: analysis.state_field,
        update_shape: analysis.state_update_shape,
        rhs_source_kind: analysis.rhs_source_kind,
        rhs_source_field: analysis.rhs_source_field
      }]
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

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: Array[Symbol]
    def sibling_command_behaviors_for(analysis)
      @spec.properties.filter_map do |predicate|
        next if predicate.name == analysis.predicate_name

        candidate_analysis = predicate_analysis(predicate)
        next unless candidate_analysis.state_type == analysis.state_type
        next unless candidate_analysis.command_confidence != :low

        case candidate_analysis.state_update_shape
        when :append_like then :append
        when :remove_last then :pop
        when :remove_first then :dequeue
        else
          case candidate_analysis.transition_kind
          when :append, :pop, :dequeue then candidate_analysis.transition_kind
          else nil
          end
        end
      end.uniq
    end

    # @rbs return: Array[String]
    def config_support_lines
      SupportModuleRenderer.new(self).render_lines
    end

    def spec_document = @spec

    def structured_collection_state?(analysis) = @state_shape_inspector.structured_collection_state?(analysis)
    def stable_companion_collection_state?(analysis) = @state_shape_inspector.stable_companion_collection_state?(analysis)
    def projection_collection_state?(analysis) = @state_shape_inspector.projection_collection_state?(analysis)
    def companion_scalar_fields_for(analysis) = @state_shape_inspector.companion_scalar_fields_for(analysis)
    def structured_scalar_state?(analysis) = @state_shape_inspector.structured_scalar_state?(analysis)
    def single_scalar_state_field_for(analyses) = @state_shape_inspector.single_scalar_state_field_for(analyses)
    def default_scalar_placeholder_for(field) = @state_shape_inspector.default_scalar_placeholder_for(field)
    def state_type_fields_for(analysis) = @state_shape_inspector.state_type_fields_for(analysis)
    def stable_companion_scalar_field?(field) = @state_shape_inspector.stable_companion_scalar_field?(field)
    def collection_state_expr(state_var, analysis) = @state_shape_inspector.collection_state_expr(state_var, analysis)
    def capacity_state_expr(state_var, analysis) = @state_shape_inspector.capacity_state_expr(state_var, analysis)
    def scalar_state_expr(state_var, analysis) = @state_shape_inspector.scalar_state_expr(state_var, analysis)
    def guard_state_expr(state_var, analysis) = @state_shape_inspector.guard_state_expr(state_var, analysis)
    def scalar_argument_domain_expr(state_var, analysis) = @state_shape_inspector.scalar_argument_domain_expr(state_var, analysis)
    def scalar_state_update_expr(state_var, analysis, updated_scalar_expr) = @state_shape_inspector.scalar_state_update_expr(state_var, analysis, updated_scalar_expr)
    def collection_state_update_expr(state_var, analysis, updated_collection_expr) = @state_shape_inspector.collection_state_update_expr(state_var, analysis, updated_collection_expr)

# @rbs predicate: Core::Entity
# @rbs return: StatefulPredicateAnalysis
def predicate_analysis(predicate)
      @predicate_analyses ||= {} #: Hash[String, StatefulPredicateAnalysis]
      @predicate_analyses[predicate.name] ||= @predicate_analyzer.analyze(predicate)
    end

    # @rbs analysis: StatefulPredicateAnalysis?
    # @rbs fallback: String
    # @rbs return: String
    def expected_result_expr_for(analysis, fallback:)
      return fallback unless analysis

      case analysis.result_position
      when :first then "before_state.first"
      when :last then "before_state.last"
      else fallback
      end
    end

    # @rbs analysis: StatefulPredicateAnalysis?
    # @rbs return: bool
    def collection_like_state?(analysis)
      return true unless analysis

      ["seq", "set"].include?(analysis.state_field_multiplicity)
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: bool
    def guard_supportable?(analysis)
      guard = guard_for(analysis)
      return true if bounded_scalar_arg_generation?(analysis)
      return true if collection_like_state?(analysis) && guard.kind == :non_empty
      return true if collection_like_state?(analysis) && guard.kind == :below_capacity && !capacity_state_expr("state", analysis).nil?
      return true if collection_like_state?(analysis) && guard.kind == :state_equals_constant && !guard.constant.nil?
      return true if !collection_like_state?(analysis) && guard.kind == :non_empty
      return true if !collection_like_state?(analysis) && guard.kind == :state_equals_constant && !guard.constant.nil?

      false
    end

    # @rbs analysis: StatefulPredicateAnalysis?
    # @rbs return: String
    def state_target_label(analysis)
      return "unknown" unless analysis
      return analysis.state_type.to_s if analysis.state_field.nil?

      "#{analysis.state_type}##{analysis.state_field}"
    end

    # @rbs state_expr: String
    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: String
    def observed_state_expected_expr(state_expr, analysis)
      if projection_collection_state?(analysis)
        state_expr
      elsif structured_collection_state?(analysis)
        "#{state_expr}[:#{analysis.state_field}]"
      else
        state_expr
      end
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: Array[String]
    def command_confidence_hint_lines(analysis)
      return [] if analysis.command_confidence == :high

      [
        "    # Analyzer command confidence: #{analysis.command_confidence}",
        "    # TODO: confirm this predicate should be modeled as a command"
      ]
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: String
    def scalar_update_guidance(analysis)
      case analysis.state_update_shape
      when :replace_with_arg
        "replace #{state_target_label(analysis)} using args"
      when :replace_value
        "replace #{state_target_label(analysis)} using args/result"
      when :increment
        "increment #{state_target_label(analysis)} based on args/result"
      when :decrement
        "decrement #{state_target_label(analysis)} based on args/result"
      else
        "update #{state_target_label(analysis)} based on args/result"
      end
    end

    # @rbs state_var: String
    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: String?
    def scalar_replace_source_expr(state_var, analysis)
      return nil unless analysis.rhs_source_kind == :state_field
      return nil if analysis.rhs_source_field.nil?

      if structured_scalar_state?(analysis)
        "#{state_var}[:#{analysis.rhs_source_field}]"
      elsif analysis.rhs_source_field == analysis.state_field
        state_var
      else
        nil
      end
    end

    # @rbs state_var: String
    # @rbs update: Hash[Symbol, untyped]
    # @rbs return: String
    def scalar_field_update_expr(state_var, update)
      field_expr = "#{state_var}[:#{update[:field]}]"

      case update[:update_shape]
      when :increment
        update[:rhs_source_kind] == :arg ? "#{field_expr} + delta" : "#{field_expr} + 1"
      when :decrement
        update[:rhs_source_kind] == :arg ? "#{field_expr} - delta" : "#{field_expr} - 1"
      when :replace_with_arg
        "#{support_module_name}.scalar_model_arg(name, args)"
      when :replace_constant
        update[:rhs_constant] || field_expr
      when :replace_value
        source_field = update[:rhs_source_field]
        source_field ? "#{state_var}[:#{source_field}]" : field_expr
      when :preserve_value
        field_expr
      else
        field_expr
      end
    end

    # @rbs analysis: StatefulPredicateAnalysis?
    # @rbs return: Array[Hash[Symbol, untyped]]
    def collection_projection_updates_for(analysis)
      projection_plan_for(analysis).updates
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: String
    def collection_append_item_expr(analysis)
      projection_plan_for(analysis).append_item_expr
    end

    # @rbs analysis: StatefulPredicateAnalysis?
    # @rbs return: ProjectionPlan
    def projection_plan_for(analysis)
      @projection_plans ||= {} #: Hash[String, ProjectionPlan]
      key = analysis&.predicate_name || "__nil__"
      @projection_plans[key] ||= ProjectionPlan.new(self, analysis)
    end

    def collection_observed_reader_expr(field_name) = @state_shape_inspector.collection_observed_reader_expr(field_name)
    def numeric_scalar_field_name?(analysis, field_name) = @state_shape_inspector.numeric_scalar_field_name?(analysis, field_name)

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: bool
    def decrement_arg_bound_guard?(analysis)
      guard = guard_for(analysis)
      !collection_like_state?(analysis) &&
        guard.kind == :arg_within_state &&
        analysis.rhs_source_kind == :arg &&
        analysis.state_update_shape == :decrement
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: bool
    def replace_arg_bound_guard?(analysis)
      guard = guard_for(analysis)
      !collection_like_state?(analysis) &&
        guard.kind == :arg_within_state &&
        analysis.rhs_source_kind == :arg &&
        analysis.state_update_shape == :replace_with_arg &&
        !guard.field.nil?
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: GuardAnalysis
    def guard_for(analysis)
      analysis.guard || GuardAnalysis.new(
        kind: analysis.guard_kind,
        field: analysis.guard_field,
        constant: analysis.guard_constant,
        support_level: :structural
      )
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: bool
    def bounded_scalar_arg_generation?(analysis)
      decrement_arg_bound_guard?(analysis) || replace_arg_bound_guard?(analysis)
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: String?
    def scalar_constant_expr(analysis)
      return analysis.rhs_constant if analysis.rhs_constant

      update = scalar_field_updates_for(analysis).find { |item| item[:field] == analysis.state_field && item[:rhs_constant] }
      update && update[:rhs_constant]
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: bool
    def state_aware_scalar_arg_generation?(analysis)
      bounded_scalar_arg_generation?(analysis) &&
        analysis.argument_params.length == 1 &&
        analysis.argument_params.first.type == "Int"
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: bool
    def arg_aware_applicability?(analysis)
      bounded_scalar_arg_generation?(analysis)
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: bool
    def scalar_unit_delta?(analysis)
      return false if analysis.rhs_source_kind == :arg

      body = predicate_body_for(analysis)
      field = Regexp.escape(analysis.state_field.to_s)

      case analysis.state_update_shape
      when :increment
        body.match?(/(?:\+1|add\[#\w+\.#{field},1\])/)
      when :decrement
        body.match?(/(?:-1|sub\[#\w+\.#{field},1\])/)
      else
        false
      end
    end

    def numeric_scalar_state?(analysis) = @state_shape_inspector.numeric_scalar_state?(analysis)

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: String
    def predicate_body_for(analysis)
      predicate = @spec.properties.find { |item| item.name == analysis.predicate_name }
      predicate&.normalized_text.to_s
    end

    # @rbs name: String
    # @rbs return: bool
    def property_like_name?(name)
      name.match?(/(?:Identity|Roundtrip|Invariant|Sorted|LIFO|FIFO|IsEmpty|Empty|IsFull|Full)\z/i)
    end

    # @rbs value: String
    # @rbs return: String
    def camelize(value)
      value.to_s.split(/[^a-zA-Z0-9]+/).reject(&:empty?).map { |part| part[0].upcase + part[1..] }.join
    end

    # @rbs value: String
    # @rbs return: String
    def underscore(value)
      value
        .gsub(/([a-z\d])([A-Z])/, '\\1_\\2')
        .tr("-", "_")
        .downcase
    end
  end
end
