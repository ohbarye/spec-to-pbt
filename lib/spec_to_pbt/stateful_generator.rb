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
      lines << "      [] # TODO: replace with a domain-specific model state"
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

    # Heuristic only: parser is regex-based and loses some Alloy syntax (e.g. primed vars),
    # so use predicate names + body shape to emit a useful scaffold instead of pretending exact semantics.
    # @rbs predicate: Predicate
    # @rbs return: bool
    def command_like_predicate?(predicate)
      patterns = PropertyPattern.detect(predicate.name, predicate.body)
      return false if (patterns & EXCLUDED_COMMAND_PATTERNS).any?
      return false if property_like_name?(predicate.name)

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
        *next_state_lines(behavior),
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
    # @rbs return: Array[String]
    def next_state_lines(behavior)
      case behavior
      when :append
        [
          "    def next_state(state, args)",
          "      state + [args]",
          "    end"
        ]
      when :pop
        [
          "    def next_state(state, _args)",
          "      state[0...-1]",
          "    end"
        ]
      when :dequeue
        [
          "    def next_state(state, _args)",
          "      state.drop(1)",
          "    end"
        ]
      else
        [
          "    def next_state(state, _args)",
          "      state # TODO: model transition",
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
        lines << "      # Analyzer hints: state_field=#{analysis.state_field.inspect}, size_delta=#{analysis.size_delta.inspect}, transition_kind=#{analysis.transition_kind.inspect}, requires_non_empty_state=#{analysis.requires_non_empty_state}"
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

      case behavior
      when :append
        lines.concat([
          "      expected_size = before_state.length + 1",
          "      raise \"Expected size to increase by 1\" unless after_state.length == expected_size"
        ])
      when :pop
        lines.concat([
          "      expected = before_state.last",
          "      raise \"Expected popped value to match model\" unless result == expected",
          "      raise \"Expected size to decrease by 1\" unless after_state.length == before_state.length - 1"
        ])
      when :dequeue
        lines.concat([
          "      expected = before_state.first",
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
      @spec.assertions.filter_map do |assertion|
        references_predicate?(assertion.body, predicate_name) ? assertion.name : nil
      end
    end

    # @rbs predicate_name: String
    # @rbs return: Array[String]
    def related_facts_for(predicate_name)
      @spec.facts.filter_map do |fact|
        next unless references_predicate?(fact.body, predicate_name)

        fact.name || "<anonymous fact>"
      end
    end

    # @rbs predicate_name: String
    # @rbs return: Array[Symbol]
    def assertion_fact_pattern_hints(predicate_name)
      texts = [] #: Array[String]

      @spec.assertions.each do |assertion|
        texts << "#{assertion.name} #{assertion.body}" if references_predicate?(assertion.body, predicate_name)
      end
      @spec.facts.each do |fact|
        next unless references_predicate?(fact.body, predicate_name)

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

      state_types = state_param_types_for(command_pred)
      return [] if state_types.empty?

      @spec.predicates.select do |predicate|
        next false if predicate.name == predicate_name
        next false if command_like_predicate?(predicate)

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
