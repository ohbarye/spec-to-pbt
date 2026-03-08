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
      lines << "      #{initial_state_code}"
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
      lines = [] #: Array[String]
      lines << "# frozen_string_literal: true"
      lines << ""
      lines << "# Regeneration-safe customization file for #{module_name} stateful scaffold."
      lines << "# Edit this file to map spec command names to your real Ruby API."
      lines << "# This file is user-owned and should not be overwritten automatically."
      lines << ""
      lines << "#{config_constant_name} = {"
      lines << "  sut_factory: -> { #{sut_factory_code} },"
      lines << "  command_mappings: {"
      selected_command_predicates.each_with_index do |predicate, index|
        suffix = index == selected_command_predicates.length - 1 ? "" : ","
        lines.concat(config_command_lines(predicate, suffix))
      end
      lines << "  },"
      lines << "  verify_context: {"
      lines << "    state_reader: nil"
      lines << "  }"
      lines << "  # before_run: ->(sut) { },"
      lines << "  # after_run: ->(sut, result) { }"
      lines << "}"
      lines.join("\n")
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
      analyses = selected_command_predicates.map { |predicate| predicate_analysis(predicate) }
      return "[] # TODO: replace with a domain-specific model state" if analyses.empty?
      if analyses.all? { |analysis| collection_like_state?(analysis) }
        structured_analysis = analyses.find { |analysis| structured_collection_state?(analysis) }
        return structured_collection_initial_state_code(structured_analysis) if structured_analysis

        return "[] # TODO: replace with a domain-specific collection state"
      end

      scalar_field = single_scalar_state_field_for(analyses)
      if scalar_field
        return "#{default_scalar_placeholder_for(scalar_field)} # TODO: replace with a domain-specific scalar model state"
      end

      "nil # TODO: replace with a domain-specific scalar/model state"
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
          "      Pbt.integer(min: 1, max: state)",
          "    end"
        ]
      else
        [
          "    def arguments",
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
      class_name = "#{camelize(predicate.name)}Command"
      method_name = method_name_for(predicate)
      analysis = predicate_analysis(predicate)
      behavior = command_behavior(predicate)
      body_preview = predicate.normalized_text

      [
        "  class #{class_name}",
        *command_confidence_hint_lines(analysis),
        "    def name",
        "      :#{method_name}",
        "    end",
        "",
        *arguments_lines(predicate, analysis),
        "",
        *applicable_lines(analysis, method_name),
        "",
        *next_state_lines(analysis, behavior),
        "",
        *run_lines(method_name),
        "",
        *verify_lines(analysis, behavior, body_preview),
        "  end"
      ]
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

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs method_name: String
    # @rbs return: Array[String]
    def applicable_lines(analysis, method_name)
      state_items = collection_state_expr("state", analysis)
      if arg_aware_applicability?(analysis)
        lines = [
          "    def applicable?(state, args)",
          "      override = #{support_module_name}.applicable_override(name)",
          "      return #{support_module_name}.call_applicable_override(override, state, args) if override"
        ]
        if scalar_arg_bound_guard?(analysis)
          lines << "      delta = #{support_module_name}.scalar_model_arg(name, args)"
          lines << "      delta.is_a?(Numeric) && delta.positive? && delta <= state"
        else
          lines << "      true # TODO: refine arg-aware applicability for #{method_name}"
        end
        lines << "    end"
        return lines
      end

      lines = [
        "    def applicable?(state)",
        "      override = #{support_module_name}.applicable_override(name)",
        "      return #{support_module_name}.call_applicable_override(override, state, nil) if override"
      ]
      if collection_like_state?(analysis) && analysis.guard_kind == :non_empty
        lines << "      !#{state_items}.empty? # inferred precondition for #{method_name}"
      elsif collection_like_state?(analysis) && analysis.guard_kind == :below_capacity
        capacity_expr = capacity_state_expr("state", analysis)
        if capacity_expr
          lines << "      #{state_items}.length < #{capacity_expr} # inferred capacity/fullness guard for #{method_name}"
        else
          lines << "      true # TODO: inferred capacity/fullness guard for #{method_name}; use applicable_override or enrich the model state"
        end
      elsif !collection_like_state?(analysis) && analysis.guard_kind == :non_empty
        lines << "      state > 0 # inferred scalar precondition for #{method_name}"
      elsif analysis.guard_kind != :none
        lines << "      true # TODO: infer a scalar/domain-specific precondition"
      else
        lines << "      true"
      end
      lines << "    end"
      lines
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs behavior: Symbol
    # @rbs return: Array[String]
    def next_state_lines(analysis, behavior)
      return scalar_next_state_lines(analysis) unless collection_like_state?(analysis)
      state_items = collection_state_expr("state", analysis)

      case behavior
      when :append
        [
          "    def next_state(state, args)",
          "      # Inferred transition target: #{state_target_label(analysis)}",
          "      #{collection_state_update_expr('state', analysis, "#{state_items} + [args]")}"
        ]
      when :pop
        [
          "    def next_state(state, _args)",
          "      # Inferred transition target: #{state_target_label(analysis)}",
          "      #{collection_state_update_expr('state', analysis, "#{state_items}[0...-1]")}"
        ]
      when :dequeue
        [
          "    def next_state(state, _args)",
          "      # Inferred transition target: #{state_target_label(analysis)}",
          "      #{collection_state_update_expr('state', analysis, "#{state_items}.drop(1)")}"
        ]
      when :size_no_change
        [
          "    def next_state(state, _args)",
          "      # Inferred transition target: #{state_target_label(analysis)}",
          "      #{collection_state_update_expr('state', analysis, state_items)} # TODO: preserve size while refining element/order changes"
        ]
      else
        generic_next_state_lines(analysis)
      end + ["    end"]
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: Array[String]
    def scalar_next_state_lines(analysis)
      guidance =
        case analysis.state_update_shape
        when :increment
          "increment #{state_target_label(analysis)} based on args/result"
        when :decrement
          "decrement #{state_target_label(analysis)} based on args/result"
        when :replace_with_arg
          "replace #{state_target_label(analysis)} using args"
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
          "      delta = #{support_module_name}.scalar_model_arg(name, args)",
          "      state + delta",
          "    end"
        ]
      elsif analysis.state_update_shape == :decrement && analysis.rhs_source_kind == :arg
        [
          "    def next_state(state, args)",
          "      delta = #{support_module_name}.scalar_model_arg(name, args)",
          "      state - delta",
          "    end"
        ]
      elsif analysis.state_update_shape == :increment && scalar_unit_delta?(analysis)
        [
          "    def next_state(state, _args)",
          "      state + 1",
          "    end"
        ]
      elsif analysis.state_update_shape == :decrement && scalar_unit_delta?(analysis)
        [
          "    def next_state(state, _args)",
          "      state - 1",
          "    end"
        ]
      elsif analysis.state_update_shape == :replace_with_arg
        [
          "    def next_state(_state, args)",
          "      #{support_module_name}.scalar_model_arg(name, args)",
          "    end"
        ]
      else
        [
          "    def next_state(state, _args)",
          "      state # TODO: #{guidance}",
          "    end"
        ]
      end
    end

    # @rbs analysis: StatefulPredicateAnalysis?
    # @rbs return: Array[String]
    def generic_next_state_lines(analysis)
      if analysis && !collection_like_state?(analysis)
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
        "      result = if payload.nil?",
        "        sut.public_send(method_name)",
        "      elsif payload.is_a?(Array)",
        "        sut.public_send(method_name, *payload)",
        "      else",
        "        sut.public_send(method_name, payload)",
        "      end",
        "      adapted_result = #{support_module_name}.adapt_result(name, result)",
        "      #{support_module_name}.after_run_hook&.call(sut, adapted_result)",
        "      adapted_result",
        "    end"
      ]
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs behavior: Symbol
    # @rbs body_preview: String
    # @rbs return: Array[String]
    def verify_lines(analysis, behavior, body_preview)
      lines = [
        "    def verify!(before_state:, after_state:, args:, result:, sut:)",
        "      # TODO: translate predicate semantics into postcondition checks",
        "      # Alloy predicate body (preview): #{body_preview.inspect}",
        "      # Analyzer hints: state_field=#{analysis.state_field.inspect}, size_delta=#{analysis.size_delta.inspect}, transition_kind=#{analysis.transition_kind.inspect}, requires_non_empty_state=#{analysis.requires_non_empty_state}, scalar_update_kind=#{analysis.scalar_update_kind.inspect}, command_confidence=#{analysis.command_confidence.inspect}, guard_kind=#{analysis.guard_kind.inspect}, rhs_source_kind=#{analysis.rhs_source_kind.inspect}, state_update_shape=#{analysis.state_update_shape.inspect}"
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
      lines << "        sut: sut"
      lines << "      )"

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
      if (before_capacity_expr = capacity_state_expr("before_state", analysis))
        lines << "      before_capacity = #{before_capacity_expr}"
      end
      lines.concat(derived_verify_comment_lines(analysis))
      lines.concat(collection_verify_body(analysis, behavior))
      lines << "      [sut, args] && nil"
      lines << "    end"
      lines
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs behavior: Symbol
    # @rbs return: Array[String]
    def collection_verify_body(analysis, behavior)
      lines = [] #: Array[String]
      if analysis.derived_verify_hints.include?(:respect_non_empty_guard) && [:pop, :dequeue].include?(behavior)
        lines << "      raise \"Expected non-empty state before removal\" if before_items.empty?"
      end
      if analysis.derived_verify_hints.include?(:respect_capacity_guard) && behavior == :append && capacity_state_expr("before_state", analysis)
        lines << "      raise \"Expected available capacity before append\" unless before_items.length < before_capacity"
      end
      if analysis.derived_verify_hints.include?(:check_empty_semantics) && analysis.state_update_shape == :preserve_size
        lines << "      raise \"Expected empty-state semantics to stay aligned\" unless after_items.empty? == before_items.empty?"
      end
      lines << "      raise \"Expected size to stay the same\" unless after_items.length == before_items.length" if analysis.state_update_shape == :preserve_size

      case behavior
      when :append
        lines << "      expected_size = before_items.length + 1"
        lines << "      raise \"Expected size to increase by 1\" unless after_items.length == expected_size"
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
      [
        "  module #{support_module_name}",
        "    module_function",
        "",
        "    def config",
        "      defined?(::#{config_constant_name}) ? ::#{config_constant_name} : {}",
        "    end",
        "",
        "    def sut_factory(default_factory)",
        "      config.fetch(:sut_factory, default_factory)",
        "    end",
        "",
        "    def command_config(command_name)",
        "      config.fetch(:command_mappings, {}).fetch(command_name, {})",
        "    end",
        "",
        "    def resolve_method_name(command_name, default_method_name)",
        "      command_config(command_name).fetch(:method, default_method_name)",
        "    end",
        "",
        "    def adapt_args(command_name, args)",
        "      settings = command_config(command_name)",
        "      adapter = settings[:arg_adapter] || settings[:model_arg_adapter]",
        "      adapter ? adapter.call(args) : args",
        "    end",
        "",
        "    def model_args(command_name, args)",
        "      adapter = command_config(command_name)[:model_arg_adapter] || command_config(command_name)[:arg_adapter]",
        "      adapter ? adapter.call(args) : args",
        "    end",
        "",
        "    def scalar_model_arg(command_name, args)",
        "      payload = model_args(command_name, args)",
        "      payload.is_a?(Array) && payload.length == 1 ? payload.first : payload",
        "    end",
        "",
        "    def adapt_result(command_name, result)",
        "      adapter = command_config(command_name)[:result_adapter]",
        "      adapter ? adapter.call(result) : result",
        "    end",
        "",
        "    def applicable_override(command_name)",
        "      command_config(command_name)[:applicable_override]",
        "    end",
        "",
        "    def call_applicable_override(override, state, args)",
        "      parameters = override.parameters",
        "      if parameters.any? { |kind, _name| kind == :rest }",
        "        override.call(state, args)",
        "      else",
        "        required = parameters.count { |kind, _name| kind == :req }",
        "        optional = parameters.count { |kind, _name| kind == :opt }",
        "        if 2 >= required && 2 <= required + optional",
        "          override.call(state, args)",
        "        elsif 1 >= required && 1 <= required + optional",
        "          override.call(state)",
        "        else",
        "          override.call",
        "        end",
        "      end",
        "    end",
        "",
        "    def verify_override(command_name)",
        "      command_config(command_name)[:verify_override]",
        "    end",
        "",
        "    def state_reader",
        "      config.fetch(:verify_context, {})[:state_reader] || config[:state_reader]",
        "    end",
        "",
        "    def observed_state(sut)",
        "      reader = state_reader",
        "      reader ? reader.call(sut) : nil",
        "    end",
        "",
        "    def call_verify_override(command_name, **kwargs)",
        "      override = verify_override(command_name)",
        "      return false unless override",
        "",
        "      payload = kwargs.merge(observed_state: observed_state(kwargs[:sut]))",
        "      if override.parameters.any? { |kind, _name| kind == :keyrest }",
        "        override.call(**payload)",
        "      else",
        "        accepted = override.parameters.filter_map do |kind, name|",
        "          name if [:keyreq, :key].include?(kind)",
        "        end",
        "        accepted_payload = accepted.empty? ? {} : payload.select { |key, _value| accepted.include?(key) }",
        "        override.call(**accepted_payload)",
        "      end",
        "      true",
        "    end",
        "",
        "    def before_run_hook",
        "      config[:before_run]",
        "    end",
        "",
        "    def after_run_hook",
        "      config[:after_run]",
        "    end",
        "  end"
      ]
    end

    # @rbs predicate: Core::Entity
    # @rbs suffix: String
    # @rbs return: Array[String]
    def config_command_lines(predicate, suffix)
      method_name = method_name_for(predicate)
      suggested_method = suggested_api_method_name(predicate.name)
      lines = [
        "    #{method_name}: {",
        "      method: :#{method_name},"
      ]
      if !suggested_method.nil? && suggested_method != method_name.to_sym
        lines << "      # Suggested real API method: :#{suggested_method}"
      end
      lines << "      # arg_adapter: ->(args) { args },"
      lines << "      # model_arg_adapter: ->(args) { args },"
      lines << "      # result_adapter: ->(result) { result },"
      lines << "      # applicable_override: ->(state, args = nil) { true },"
      lines << "      # verify_override: ->(before_state:, after_state:, args:, result:, sut:, observed_state:) { nil }"
      lines << "    }#{suffix}"
      lines
    end

    # @rbs analysis: StatefulPredicateAnalysis?
    # @rbs return: bool
    def structured_collection_state?(analysis)
      return false unless analysis
      return false unless collection_like_state?(analysis)

      !companion_scalar_fields_for(analysis).empty?
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: Array[Core::Field]
    def companion_scalar_fields_for(analysis)
      return [] unless analysis.state_type

      type_entity = @spec.types.find { |item| item.name == analysis.state_type }
      return [] unless type_entity

      type_entity.fields.reject do |field|
        field.name == analysis.state_field || ["seq", "set"].include?(field.multiplicity)
      end
    end

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

    # @rbs analyses: Array[StatefulPredicateAnalysis]
    # @rbs return: Core::Field?
    def single_scalar_state_field_for(analyses)
      state_types = analyses.map(&:state_type).compact.uniq
      return nil unless state_types.length == 1

      state_fields = analyses.map(&:state_field).compact.uniq
      return nil unless state_fields.length == 1

      type_entity = @spec.types.find { |item| item.name == state_types.first }
      return nil unless type_entity
      return nil unless type_entity.fields.length == 1

      field = type_entity.fields.first
      return nil if ["seq", "set"].include?(field.multiplicity)
      return nil unless field.name == state_fields.first

      field
    end

    # @rbs field: Core::Field
    # @rbs return: String
    def default_scalar_placeholder_for(field)
      return "3" if field.name.match?(/capacity|limit|max(?:imum)?/i)
      return "0" if field.type == "Int"
      return "nil" if field.multiplicity == "lone"

      "nil"
    end

    # @rbs state_var: String
    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: String
    def collection_state_expr(state_var, analysis)
      if structured_collection_state?(analysis)
        "#{state_var}[:#{analysis.state_field}]"
      else
        state_var
      end
    end

    # @rbs state_var: String
    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: String?
    def capacity_state_expr(state_var, analysis)
      field = companion_scalar_fields_for(analysis).find { |item| item.name.match?(/capacity|limit|max(?:imum)?/i) }
      return nil unless field

      "#{state_var}[:#{field.name}]"
    end

    # @rbs state_var: String
    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs updated_collection_expr: String
    # @rbs return: String
    def collection_state_update_expr(state_var, analysis, updated_collection_expr)
      if structured_collection_state?(analysis)
        "#{state_var}.merge(#{analysis.state_field}: #{updated_collection_expr})"
      else
        updated_collection_expr
      end
    end

    # @rbs predicate_name: String
    # @rbs return: Symbol?
    def suggested_api_method_name(predicate_name)
      return :push if predicate_name.match?(/\APush/i)
      return :pop if predicate_name.match?(/\APop/i)
      return :enqueue if predicate_name.match?(/\AEnqueue/i)
      return :dequeue if predicate_name.match?(/\ADequeue/i)
      return :set_target if predicate_name.match?(/\ASetTarget/i)

      nil
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: Array[String]
    def scalar_verify_body(analysis)
      lines =
        case analysis.state_update_shape
      when :increment
        if analysis.rhs_source_kind == :arg
          [
            "      delta = #{support_module_name}.scalar_model_arg(name, args)",
            "      raise \"Expected incremented value for #{state_target_label(analysis)}\" unless after_state == before_state + delta"
          ]
        elsif scalar_unit_delta?(analysis)
          [
            "      raise \"Expected incremented value for #{state_target_label(analysis)}\" unless after_state == before_state + 1"
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
            "      raise \"Expected decremented value for #{state_target_label(analysis)}\" unless after_state == before_state - delta"
          ]
          if scalar_arg_bound_guard?(analysis)
            lines.unshift("      raise \"Expected sufficient scalar state before decrement\" unless delta <= before_state")
          end
          lines
        elsif scalar_unit_delta?(analysis)
          [
            "      raise \"Expected decremented value for #{state_target_label(analysis)}\" unless after_state == before_state - 1"
          ]
        else
          [
            "      # TODO: verify decremented value for #{state_target_label(analysis)}",
            "      # Example shape: after_state should reflect a monotonic -1 style update"
          ]
        end
      when :replace_with_arg
        [
          "      expected = #{support_module_name}.scalar_model_arg(name, args)",
          "      raise \"Expected replaced value for #{state_target_label(analysis)}\" unless after_state == expected"
        ]
      when :replace_value
        [
          "      # TODO: verify replaced value for #{state_target_label(analysis)}",
          "      # Example shape: compare the inferred target against args/result"
        ]
      when :preserve_value
        [
          "      raise \"Expected preserved value for #{state_target_label(analysis)}\" unless after_state == before_state",
          "      # Example shape: replace this equality check with a narrower field-level assertion if needed"
        ]
      else
        [
          "      # TODO: #{scalar_verify_guidance(analysis)}"
        ]
      end

      if numeric_scalar_state?(analysis) && analysis.derived_verify_hints.include?(:check_non_negative_scalar_state)
        lines << "      raise \"Expected non-negative value for #{state_target_label(analysis)}\" unless after_state >= 0"
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
      if analysis.derived_verify_hints.include?(:check_non_negative_scalar_state)
        lines << "      # Derived from related assertions/facts: keep non-negative scalar invariants aligned with the model state"
      end

      lines
    end

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

    # @rbs analysis: StatefulPredicateAnalysis?
    # @rbs return: String
    def state_target_label(analysis)
      return "unknown" unless analysis
      return analysis.state_type.to_s if analysis.state_field.nil?

      "#{analysis.state_type}##{analysis.state_field}"
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

    # @rbs analysis: StatefulPredicateAnalysis?
    # @rbs return: String
    def scalar_verify_guidance(analysis)
      return "verify scalar/domain-specific postconditions" unless analysis

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
    # @rbs return: bool
    def scalar_arg_bound_guard?(analysis)
      !collection_like_state?(analysis) &&
        analysis.guard_kind == :arg_within_state &&
        analysis.rhs_source_kind == :arg &&
        analysis.state_update_shape == :decrement
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: bool
    def state_aware_scalar_arg_generation?(analysis)
      scalar_arg_bound_guard?(analysis) &&
        analysis.argument_params.length == 1 &&
        analysis.argument_params.first.type == "Int"
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: bool
    def arg_aware_applicability?(analysis)
      scalar_arg_bound_guard?(analysis)
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

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: bool
    def numeric_scalar_state?(analysis)
      return false unless analysis.state_type && analysis.state_field

      type_entity = @spec.types.find { |item| item.name == analysis.state_type }
      return false unless type_entity

      field = type_entity.fields.find { |item| item.name == analysis.state_field }
      field&.type == "Int"
    end

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
