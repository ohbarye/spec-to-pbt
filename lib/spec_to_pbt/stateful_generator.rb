# frozen_string_literal: true

# rbs_inline: enabled

module SpecToPbt
  # Generates a stateful PBT scaffold that targets `Pbt.stateful`.
  class StatefulGenerator
    PRIMITIVE_TYPES = ["Int", "String"].freeze #: Array[String]
    EXCLUDED_COMMAND_PATTERNS = [:roundtrip, :ordering, :invariant, :idempotent, :empty].freeze #: Array[Symbol]

    # @rbs spec: Spec
    # @rbs return: void
    def initialize(spec)
      @spec = spec #: Spec
      @type_inferrer = TypeInferrer.new(spec) #: TypeInferrer
      @predicate_analyzer = StatefulPredicateAnalyzer.new(spec) #: StatefulPredicateAnalyzer
    end

    # @rbs return: String
    def generate
      lines = [] #: Array[String]
      lines << "# frozen_string_literal: true"
      lines << ""
      lines << 'require "pbt"'
      lines << 'require "rspec"'
      lines << %(require_relative "#{module_name}_impl")
      lines << ""
      lines << %(RSpec.describe "#{module_name} (stateful scaffold)" do)
      lines << "  it \"wires a stateful PBT scaffold (customize before enabling)\" do"
      lines << '    unless ENV["ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD"] == "1"'
      lines << '      skip "Set ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 after customizing the generated scaffold"'
      lines << "    end"
      lines << ""
      lines << "    Pbt.assert(worker: :none, num_runs: 5, seed: 1) do"
      lines << "      Pbt.stateful("
      lines << "        model: #{model_class_name}.new,"
      lines << "        sut: -> { #{sut_factory_code} },"
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

    private

    # @rbs return: String
    def module_name
      @spec.module_name || "operation"
    end

    # @rbs return: String
    def model_class_name
      "#{camelize(module_name)}Model"
    end

    # @rbs return: String
    def sut_factory_code
      "#{camelize(module_name)}Impl.new"
    end

    # @rbs return: Array[Predicate]
    def selected_command_predicates
      @selected_command_predicates ||= @spec.predicates.select { |predicate| command_like_predicate?(predicate) } #: Array[Predicate]
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
      return "[] # TODO: replace with a domain-specific collection state" if analyses.all? { |analysis| collection_like_state?(analysis) }

      "nil # TODO: replace with a domain-specific scalar/model state"
    end

    # @rbs predicate: Predicate
    # @rbs return: bool
    def command_like_predicate?(predicate)
      analysis = predicate_analysis(predicate)
      patterns = PropertyPattern.detect(predicate.name, predicate.normalized_body)
      return false if (patterns & EXCLUDED_COMMAND_PATTERNS).any?
      return false if property_like_name?(predicate.name)
      return false if analysis.command_confidence == :low

      [:append, :pop, :dequeue, :size_no_change].include?(analysis.transition_kind) ||
        analysis.state_update_shape != :unknown ||
        analysis.guard_kind != :none
    end

    # @rbs predicate: Predicate
    # @rbs return: Array[Hash[Symbol, String]]
    def argument_params(predicate)
      predicate_analysis(predicate).argument_params
    end

    # @rbs predicate: Predicate
    # @rbs return: String
    def arguments_code(predicate)
      params = argument_params(predicate)
      return "Pbt.nil" if params.empty?

      arbitraries = params.map { |param| arbitrary_code_for(param[:type]) }
      return arbitraries.first if arbitraries.size == 1

      "Pbt.tuple(#{arbitraries.join(', ')})"
    end

    # @rbs type_name: String
    # @rbs return: String
    def arbitrary_code_for(type_name)
      code = @type_inferrer.generator_for(type_name)
      return code if PRIMITIVE_TYPES.include?(type_name)

      "#{code} # placeholder for #{type_name}"
    end

    # @rbs predicate: Predicate
    # @rbs return: Symbol
    def command_behavior(predicate)
      analysis = predicate_analysis(predicate)
      return :append if [:append, :append_like].include?(analysis.state_update_shape) || analysis.transition_kind == :append
      return :dequeue if analysis.state_update_shape == :remove_first || analysis.transition_kind == :dequeue
      return :pop if analysis.state_update_shape == :remove_last || analysis.transition_kind == :pop
      return :size_no_change if analysis.state_update_shape == :preserve_size || analysis.transition_kind == :size_no_change

      :unknown
    end

    # @rbs predicate: Predicate
    # @rbs return: String
    def method_name_for(predicate)
      underscore(predicate.name)
    end

    # @rbs predicate: Predicate
    # @rbs return: Array[String]
    def command_class_lines(predicate)
      class_name = "#{camelize(predicate.name)}Command"
      method_name = method_name_for(predicate)
      analysis = predicate_analysis(predicate)
      behavior = command_behavior(predicate)
      body_preview = predicate.normalized_body

      [
        "  class #{class_name}",
        *command_confidence_hint_lines(analysis),
        "    def name",
        "      :#{method_name}",
        "    end",
        "",
        "    def arguments",
        "      #{arguments_code(predicate)}",
        "    end",
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
      return [
        "    def applicable?(state)",
        "      !state.empty? # inferred precondition for #{method_name}",
        "    end"
      ] if collection_like_state?(analysis) && analysis.guard_kind == :non_empty

      return [
        "    def applicable?(_state)",
        "      true # TODO: infer a scalar/domain-specific precondition",
        "    end"
      ] if analysis.guard_kind != :none

      [
        "    def applicable?(_state)",
        "      true",
        "    end"
      ]
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs behavior: Symbol
    # @rbs return: Array[String]
    def next_state_lines(analysis, behavior)
      return scalar_next_state_lines(analysis) unless collection_like_state?(analysis)

      case behavior
      when :append
        [
          "    def next_state(state, args)",
          "      # Inferred transition target: #{state_target_label(analysis)}",
          "      state + [args]"
        ]
      when :pop
        [
          "    def next_state(state, _args)",
          "      # Inferred transition target: #{state_target_label(analysis)}",
          "      state[0...-1]"
        ]
      when :dequeue
        [
          "    def next_state(state, _args)",
          "      # Inferred transition target: #{state_target_label(analysis)}",
          "      state.drop(1)"
        ]
      when :size_no_change
        [
          "    def next_state(state, _args)",
          "      # Inferred transition target: #{state_target_label(analysis)}",
          "      state # TODO: preserve size while refining element/order changes"
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

      [
        "    def next_state(state, _args)",
        "      state # TODO: #{guidance}",
        "    end"
      ]
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
        "      if args.nil?",
        "        sut.public_send(:#{method_name})",
        "      elsif args.is_a?(Array)",
        "        sut.public_send(:#{method_name}, *args)",
        "      else",
        "        sut.public_send(:#{method_name}, args)",
        "      end",
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
      lines << "      # Suggested verify order:"
      lines << "      # 1. Command-specific postconditions"
      lines << "      # 2. Related Alloy assertions/facts"
      lines << "      # 3. Related property predicates"

      unless collection_like_state?(analysis)
        lines << "      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks"
        lines << "      # Inferred state target: #{state_target_label(analysis)}"
        lines.concat(scalar_verify_body(analysis))
        lines << "      [sut, args] && nil"
        lines << "    end"
        return lines
      end

      lines << "      # Inferred collection target: #{state_target_label(analysis)}"
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
      lines << "      raise \"Expected size to stay the same\" unless after_state.length == before_state.length" if analysis.state_update_shape == :preserve_size

      case behavior
      when :append
        lines << "      expected_size = before_state.length + 1"
        lines << "      raise \"Expected size to increase by 1\" unless after_state.length == expected_size"
      when :pop
        lines << "      expected = #{expected_result_expr_for(analysis, fallback: 'before_state.last')}"
        lines << "      raise \"Expected popped value to match model\" unless result == expected"
        lines << "      raise \"Expected size to decrease by 1\" unless after_state.length == before_state.length - 1"
      when :dequeue
        lines << "      expected = #{expected_result_expr_for(analysis, fallback: 'before_state.first')}"
        lines << "      raise \"Expected dequeued value to match model\" unless result == expected"
        lines << "      raise \"Expected size to decrease by 1\" unless after_state.length == before_state.length - 1"
      else
        lines << "      # TODO: add concrete collection checks for #{analysis.predicate_name}"
      end

      lines
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: Array[String]
    def scalar_verify_body(analysis)
      case analysis.state_update_shape
      when :increment
        [
          "      # TODO: verify incremented value for #{state_target_label(analysis)}",
          "      # Example shape: after_state should reflect a monotonic +1 style update"
        ]
      when :decrement
        [
          "      # TODO: verify decremented value for #{state_target_label(analysis)}",
          "      # Example shape: after_state should reflect a monotonic -1 style update"
        ]
      when :replace_with_arg
        [
          "      # TODO: verify replaced value for #{state_target_label(analysis)} using args",
          "      # Example shape: compare the inferred target against the command argument"
        ]
      when :replace_value
        [
          "      # TODO: verify replaced value for #{state_target_label(analysis)}",
          "      # Example shape: compare the inferred target against args/result"
        ]
      when :preserve_value
        [
          "      # TODO: verify preserved value for #{state_target_label(analysis)}",
          "      # Example shape: assert the inferred target remains unchanged"
        ]
      else
        [
          "      # TODO: #{scalar_verify_guidance(analysis)}"
        ]
      end
    end

    # @rbs predicate: Predicate
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

    # @rbs name: String
    # @rbs return: bool
    def property_like_name?(name)
      name.match?(/(?:Identity|Roundtrip|Invariant|Sorted|LIFO|FIFO|IsEmpty|Empty)\z/i)
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
