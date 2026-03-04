# frozen_string_literal: true

# rbs_inline: enabled

module SpecToPbt
  # Generates a stateful PBT scaffold that targets `Pbt.stateful`.
  # This is intentionally a scaffold (not a complete translator): it emits
  # a runnable skeleton with TODO placeholders for model transitions and SUT wiring.
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
        suffix = (index == command_class_names.length - 1) ? "" : ","
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

    # @rbs return: Array[String]
    def signature_names
      @signature_names ||= @spec.signatures.map(&:name) #: Array[String]
    end

    # @rbs return: String?
    def state_signature_name
      @state_signature_name ||= signature_names.find { |name| name == camelize(module_name) }
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

    # Heuristic only: parser is regex-based and loses some Alloy syntax (e.g. primed vars),
    # so use predicate names + body shape to emit a useful scaffold instead of pretending exact semantics.
    # @rbs predicate: Predicate
    # @rbs return: bool
    def command_like_predicate?(predicate)
      analysis = predicate_analysis(predicate)
      patterns = PropertyPattern.detect(predicate.name, predicate.body)
      return false if (patterns & EXCLUDED_COMMAND_PATTERNS).any?
      return false if property_like_name?(predicate.name)
      return false if analysis.command_confidence == :low
      return true if transition_evidence?(analysis)

      verb_like_name?(predicate.name) || transition_like_body?(predicate.body)
    end

    # @rbs name: String
    # @rbs return: bool
    def verb_like_name?(name)
      name.match?(/\A(?:Push|Pop|Enqueue|Dequeue|Add|Remove|Insert|Delete|Put|Get)/)
    end

    # @rbs name: String
    # @rbs return: bool
    def property_like_name?(name)
      name.match?(/(?:Identity|Roundtrip|Invariant|Sorted|LIFO|FIFO|IsEmpty|Empty)\z/i)
    end

    # @rbs body: String
    # @rbs return: bool
    def transition_like_body?(body)
      body.include?("'") && body.match?(/[#=]/)
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

      arbitaries = params.map { |param| arbitrary_code_for(param[:type]) }
      return arbitaries.first if arbitaries.size == 1

      "Pbt.tuple(#{arbitaries.join(', ')})"
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
      return analysis.transition_kind if analysis.transition_kind

      name = predicate.name
      return :append if name.match?(/\A(?:Push|Enqueue|Add|Insert|Put)/)
      return :dequeue if name.match?(/\ADequeue/)
      return :pop if name.match?(/\A(?:Pop|Remove|Delete|Get)/)

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
      body_preview = predicate.body.lines.map(&:strip).reject(&:empty?).join(" ")

      [
        "  class #{class_name}",
        "    def name",
        "      :#{method_name}",
        "    end",
        "",
        "    def arguments",
        "      #{arguments_code(predicate)}",
        "    end",
        "",
        *applicable_lines(behavior, method_name),
        "",
        *next_state_lines(behavior, analysis),
        "",
        *run_lines(method_name),
        "",
        *verify_lines(behavior, predicate.name, body_preview),
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

    # @rbs behavior: Symbol
    # @rbs method_name: String
    # @rbs return: Array[String]
    def applicable_lines(behavior, method_name)
      analysis = predicate_analysis_by_method_name(method_name)
      if analysis&.requires_non_empty_state || [:pop, :dequeue].include?(behavior)
        unless collection_like_state?(analysis)
          return [
            "    def applicable?(_state)",
            "      true # TODO: infer a scalar/domain-specific precondition",
            "    end"
          ]
        end

        [
          "    def applicable?(state)",
          "      !state.empty? # inferred precondition for #{method_name}",
          "    end"
        ]
      else
        [
          "    def applicable?(_state)",
          "      true",
          "    end"
        ]
      end
    end

    # @rbs behavior: Symbol
    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: Array[String]
    def next_state_lines(behavior, analysis)
      return generic_next_state_lines(analysis) unless collection_like_state?(analysis)

      case behavior
      when :append
        [
          "    def next_state(state, args)",
          "      # Inferred transition target: #{state_target_label(analysis)}",
          "      state + [args]",
          "    end"
        ]
      when :pop
        [
          "    def next_state(state, _args)",
          "      # Inferred transition target: #{state_target_label(analysis)}",
          "      state[0...-1]",
          "    end"
        ]
      when :dequeue
        [
          "    def next_state(state, _args)",
          "      # Inferred transition target: #{state_target_label(analysis)}",
          "      state.drop(1)",
          "    end"
        ]
      when :size_no_change
        [
          "    def next_state(state, _args)",
          "      # Inferred transition target: #{state_target_label(analysis)}",
          "      state # inferred size-preserving transition (customize shape change if needed)",
          "    end"
        ]
      else
        generic_next_state_lines(analysis)
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

    # @rbs behavior: Symbol
    # @rbs predicate_name: String
    # @rbs body_preview: String
    # @rbs return: Array[String]
    def verify_lines(behavior, predicate_name, body_preview)
      analysis = predicate_analysis_by_name(predicate_name)
      related_assertions = related_assertions_for(predicate_name)
      related_facts = related_facts_for(predicate_name)
      assertion_fact_hints = assertion_fact_pattern_hints(predicate_name)
      related_property_predicates = related_property_predicates_for(predicate_name)
      related_property_predicate_hints = related_property_predicate_pattern_hints(predicate_name)

      lines = [
        "    def verify!(before_state:, after_state:, args:, result:, sut:)",
        "      # TODO: translate predicate semantics into postcondition checks",
        "      # Alloy predicate body (preview): #{body_preview.inspect}"
      ]
      if analysis
        lines << "      # Analyzer hints: state_field=#{analysis.state_field.inspect}, size_delta=#{analysis.size_delta.inspect}, transition_kind=#{analysis.transition_kind.inspect}, requires_non_empty_state=#{analysis.requires_non_empty_state}, scalar_update_kind=#{analysis.scalar_update_kind.inspect}"
      end
      if related_assertions.any?
        lines << "      # Related Alloy assertions: #{related_assertions.join(', ')}"
      end
      if related_facts.any?
        lines << "      # Related Alloy facts: #{related_facts.join(', ')}"
      end
      if assertion_fact_hints.any?
        lines << "      # Assertion/fact pattern hints: #{assertion_fact_hints.map(&:to_s).join(', ')}"
      end
      if related_property_predicates.any?
        lines << "      # Related Alloy property predicates: #{related_property_predicates.join(', ')}"
      end
      if related_property_predicate_hints.any?
        lines << "      # Related property predicate pattern hints: #{related_property_predicate_hints.map(&:to_s).join(', ')}"
      end
      lines << "      # Suggested verify order:"
      lines << "      # 1. Command-specific postconditions"
      lines << "      # 2. Related Alloy assertions/facts"
      lines << "      # 3. Related property predicates"

      unless collection_like_state?(analysis)
        lines << "      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks"
        lines << "      # Inferred state target: #{state_target_label(analysis)}"
        lines << "      # TODO: #{scalar_verify_guidance(analysis)}"
        lines << "      [sut, args] && nil"
        lines << "    end"
        return lines
      end

      lines << "      # Inferred collection target: #{state_target_label(analysis)}"

      if analysis && analysis.size_delta == 0
        lines.concat([
          "      raise \"Expected size to stay the same\" unless after_state.length == before_state.length"
        ])
      end

      case behavior
      when :append
        lines.concat([
          "      expected_size = before_state.length + 1",
          "      raise \"Expected size to increase by 1\" unless after_state.length == expected_size"
        ])
      when :pop
        expected_expr = expected_result_expr_for(analysis, fallback: "before_state.last")
        lines.concat([
          "      expected = #{expected_expr}",
          "      raise \"Expected popped value to match model\" unless result == expected",
          "      raise \"Expected size to decrease by 1\" unless after_state.length == before_state.length - 1"
        ])
      when :dequeue
        expected_expr = expected_result_expr_for(analysis, fallback: "before_state.first")
        lines.concat([
          "      expected = #{expected_expr}",
          "      raise \"Expected dequeued value to match model\" unless result == expected",
          "      raise \"Expected size to decrease by 1\" unless after_state.length == before_state.length - 1"
        ])
      else
        lines << "      # TODO: add concrete checks for #{predicate_name}"
      end

      lines << "      [sut, args] && nil"
      lines << "    end"
      lines
    end

    # @rbs predicate_name: String
    # @rbs return: Array[String]
    def related_assertions_for(predicate_name)
      analysis = predicate_analysis_by_name(predicate_name)
      @spec.assertions.filter_map do |assertion|
        next unless references_predicate?(assertion.body, predicate_name)
        next unless related_text_matches_analysis?(assertion.body, analysis)

        assertion.name
      end
    end

    # @rbs predicate_name: String
    # @rbs return: Array[String]
    def related_facts_for(predicate_name)
      analysis = predicate_analysis_by_name(predicate_name)
      @spec.facts.filter_map do |fact|
        next unless references_predicate?(fact.body, predicate_name)
        next unless related_text_matches_analysis?(fact.body, analysis)

        fact.name || "<anonymous fact>"
      end
    end

    # @rbs predicate_name: String
    # @rbs return: Array[Symbol]
    def assertion_fact_pattern_hints(predicate_name)
      analysis = predicate_analysis_by_name(predicate_name)
      texts = [] #: Array[String]

      @spec.assertions.each do |assertion|
        next unless references_predicate?(assertion.body, predicate_name)
        next unless related_text_matches_analysis?(assertion.body, analysis)

        texts << "#{assertion.name} #{assertion.body}"
      end
      @spec.facts.each do |fact|
        next unless references_predicate?(fact.body, predicate_name)
        next unless related_text_matches_analysis?(fact.body, analysis)

        fact_name = fact.name || ""
        texts << "#{fact_name} #{fact.body}".strip
      end

      texts.flat_map { |text| PropertyPattern.detect("", text) }.uniq
    end

    # @rbs predicate_name: String
    # @rbs return: Array[Predicate]
    def related_property_predicates(predicate_name)
      command_pred = @spec.predicates.find { |predicate| predicate.name == predicate_name }
      return [] unless command_pred

      analysis = predicate_analysis(command_pred)
      state_types = [analysis.state_type].compact
      state_types = state_param_types_for(command_pred) if state_types.empty?
      return [] if state_types.empty?

      @spec.predicates.select do |predicate|
        next false if predicate.name == predicate_name
        next false if command_like_predicate?(predicate)
        next false unless related_predicate_matches_analysis?(predicate, analysis)

        predicate.params.any? { |param| state_types.include?(param[:type]) }
      end
    end

    # @rbs predicate: Predicate
    # @rbs return: StatefulPredicateAnalysis
    def predicate_analysis(predicate)
      @predicate_analyses ||= {} #: Hash[String, StatefulPredicateAnalysis]
      @predicate_analyses[predicate.name] ||= @predicate_analyzer.analyze(predicate)
    end

    # @rbs predicate_name: String
    # @rbs return: StatefulPredicateAnalysis?
    def predicate_analysis_by_name(predicate_name)
      predicate = @spec.predicates.find { |item| item.name == predicate_name }
      predicate ? predicate_analysis(predicate) : nil
    end

    # @rbs method_name: String
    # @rbs return: StatefulPredicateAnalysis?
    def predicate_analysis_by_method_name(method_name)
      predicate = @spec.predicates.find { |item| underscore(item.name) == method_name }
      predicate ? predicate_analysis(predicate) : nil
    end

    # @rbs predicate_name: String
    # @rbs return: Array[String]
    def related_property_predicates_for(predicate_name)
      related_property_predicates(predicate_name).map(&:name)
    end

    # @rbs predicate_name: String
    # @rbs return: Array[Symbol]
    def related_property_predicate_pattern_hints(predicate_name)
      related_property_predicates(predicate_name)
        .flat_map { |predicate| PropertyPattern.detect(predicate.name, predicate.body) }
        .uniq
    end

    # @rbs predicate: Predicate
    # @rbs return: Array[String]
    def state_param_types_for(predicate)
      primed_state_types = [] #: Array[String]
      params_by_name = predicate.params.to_h { |param| [param[:name], param] }

      predicate.params.each do |param|
        name = param[:name]
        next unless name.end_with?("'")

        base_name = name.delete_suffix("'")
        base_param = params_by_name[base_name]
        next unless base_param
        next unless base_param[:type] == param[:type]

        primed_state_types << param[:type]
      end

      if primed_state_types.empty? && state_signature_name
        [state_signature_name]
      else
        primed_state_types.uniq
      end
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

    # @rbs return: Array[String]
    def generic_next_state_lines(analysis)
      if analysis && !collection_like_state?(analysis)
        [
          "    def next_state(state, _args)",
          "      state # TODO: #{scalar_update_guidance(analysis)}",
          "    end"
        ]
      else
        [
          "    def next_state(state, _args)",
          "      state # TODO: model transition (analyzer could not infer a collection-safe update)",
          "    end"
        ]
      end
    end

    # @rbs analysis: StatefulPredicateAnalysis?
    # @rbs return: String
    def state_target_label(analysis)
      return "unknown" unless analysis
      return analysis.state_type.to_s if analysis.state_field.nil?

      "#{analysis.state_type}##{analysis.state_field}"
    end

    # @rbs analysis: StatefulPredicateAnalysis?
    # @rbs return: bool
    def transition_evidence?(analysis)
      return false unless analysis

      !analysis.transition_kind.nil? || !analysis.size_delta.nil? || analysis.requires_non_empty_state
    end

    # @rbs analysis: StatefulPredicateAnalysis
    # @rbs return: String
    def scalar_update_guidance(analysis)
      case analysis.scalar_update_kind
      when :replace_like
        "replace #{state_target_label(analysis)} using args/result"
      when :increment_like
        "update #{state_target_label(analysis)} based on args/result"
      when :decrement_like
        "decrease #{state_target_label(analysis)} based on args/result"
      else
        "update #{state_target_label(analysis)} based on args/result"
      end
    end

    # @rbs analysis: StatefulPredicateAnalysis?
    # @rbs return: String
    def scalar_verify_guidance(analysis)
      return "verify scalar/domain-specific postconditions" unless analysis

      case analysis.scalar_update_kind
      when :replace_like
        "verify replaced value for #{state_target_label(analysis)}"
      when :increment_like
        "verify incremented value for #{state_target_label(analysis)}"
      when :decrement_like
        "verify decremented value for #{state_target_label(analysis)}"
      else
        "verify scalar/domain-specific postconditions for #{state_target_label(analysis)}"
      end
    end

    # @rbs text: String
    # @rbs analysis: StatefulPredicateAnalysis?
    # @rbs return: bool
    def related_text_matches_analysis?(text, analysis)
      return true unless analysis

      state_matches = analysis.state_type.nil? || text.match?(/\b#{Regexp.escape(analysis.state_type)}\b/)
      field_matches = analysis.state_field.nil? || text.match?(/\b#{Regexp.escape(analysis.state_field)}\b/)

      state_matches || field_matches
    end

    # @rbs predicate: Predicate
    # @rbs analysis: StatefulPredicateAnalysis?
    # @rbs return: bool
    def related_predicate_matches_analysis?(predicate, analysis)
      return true unless analysis

      predicate_analysis = predicate_analysis(predicate)
      return true if predicate_analysis.state_type == analysis.state_type
      return true if predicate_analysis.state_field == analysis.state_field && !analysis.state_field.nil?

      related_text_matches_analysis?(predicate.body, analysis)
    end

    # @rbs body: String
    # @rbs predicate_name: String
    # @rbs return: bool
    def references_predicate?(body, predicate_name)
      body.match?(/\b#{Regexp.escape(predicate_name)}\s*\[/)
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
