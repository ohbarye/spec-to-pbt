# frozen_string_literal: true

# rbs_inline: enabled

module SpecToPbt
  StatefulPredicateAnalysis = Data.define(
    :predicate_name,
    :state_param_names,
    :state_type,
    :argument_params,
    :state_field,
    :size_delta,
    :requires_non_empty_state,
    :transition_kind,
    :result_position
  ) do
    # @rbs predicate_name: String
    # @rbs state_param_names: Array[String]
    # @rbs state_type: String?
    # @rbs argument_params: Array[Hash[Symbol, String]]
    # @rbs state_field: String?
    # @rbs size_delta: Integer?
    # @rbs requires_non_empty_state: bool
    # @rbs transition_kind: Symbol?
    # @rbs result_position: Symbol?
    # @rbs return: void
    def initialize(predicate_name:, state_param_names: [], state_type: nil, argument_params: [], state_field: nil, size_delta: nil, requires_non_empty_state: false, transition_kind: nil, result_position: nil) = super
  end

  # Extracts minimal stateful command hints from a predicate body.
  class StatefulPredicateAnalyzer
    # @rbs spec: Spec
    # @rbs return: void
    def initialize(spec)
      @spec = spec #: Spec
      @signature_names = spec.signatures.map(&:name) #: Array[String]
      @module_state_name = spec.module_name&.then { |name| camelize(name) } #: String?
    end

    # @rbs predicate: Predicate
    # @rbs return: StatefulPredicateAnalysis
    def analyze(predicate)
      state_param_names, state_type = infer_state_params(predicate)
      argument_params = predicate.params.reject do |param|
        @signature_names.include?(param[:name]) || state_param_names.include?(param[:name])
      end
      if state_type
        argument_params = argument_params.reject { |param| param[:type] == state_type && state_param_names.include?(param[:name]) }
      end

      state_field = infer_state_field(predicate.body, state_param_names)
      size_delta = infer_size_delta(predicate.body)
      requires_non_empty_state = requires_non_empty_state?(predicate.body)

      transition_kind = infer_transition_kind(predicate.name, size_delta, requires_non_empty_state)

      StatefulPredicateAnalysis.new(
        predicate_name: predicate.name,
        state_param_names:,
        state_type:,
        argument_params:,
        state_field:,
        size_delta:,
        requires_non_empty_state:,
        transition_kind:,
        result_position: infer_result_position(predicate.name, transition_kind)
      )
    end

    private

    # @rbs predicate: Predicate
    # @rbs return: Array[Array[String] | String?]
    def infer_state_params(predicate)
      params_by_name = predicate.params.to_h { |param| [param[:name], param] }

      predicate.params.each do |param|
        next unless param[:name].end_with?("'")

        base_name = param[:name].delete_suffix("'")
        base = params_by_name[base_name]
        next unless base
        next unless base[:type] == param[:type]

        return [[base_name, param[:name]], param[:type]]
      end

      return [[], nil] unless @module_state_name

      state_params = predicate.params.select { |param| param[:type] == @module_state_name }.map { |param| param[:name] }
      [state_params, (state_params.empty? ? nil : @module_state_name)]
    end

    # @rbs body: String
    # @rbs return: Integer?
    def infer_size_delta(body)
      return 1 if body.match?(/#\w+'?\.\w+\s*=\s*add\[/)
      return -1 if body.match?(/#\w+'?\.\w+\s*=\s*sub\[/)
      return 0 if body.match?(/#\w+'?\.\w+\s*=\s*#\w+\.?\w*/)

      nil
    end

    # @rbs body: String
    # @rbs state_param_names: Array[String]
    # @rbs return: String?
    def infer_state_field(body, state_param_names)
      state_param_names.each do |param_name|
        match = body.match(/##{Regexp.escape(param_name)}\.(\w+)/)
        return match[1] if match
      end

      match = body.match(/#\w+'?\.(\w+)/)
      match && match[1]
    end

    # @rbs body: String
    # @rbs return: bool
    def requires_non_empty_state?(body)
      body.match?(/#\w+\.?\w*\s*>\s*0/)
    end

    # @rbs predicate_name: String
    # @rbs size_delta: Integer?
    # @rbs requires_non_empty_state: bool
    # @rbs return: Symbol?
    def infer_transition_kind(predicate_name, size_delta, requires_non_empty_state)
      return :append if size_delta == 1
      return :dequeue if size_delta == -1 && predicate_name.match?(/\ADequeue/i)
      return :pop if size_delta == -1 && requires_non_empty_state
      return :size_no_change if size_delta == 0

      nil
    end

    # @rbs predicate_name: String
    # @rbs transition_kind: Symbol?
    # @rbs return: Symbol?
    def infer_result_position(predicate_name, transition_kind)
      return :first if transition_kind == :dequeue
      return :last if transition_kind == :pop
      return :first if predicate_name.match?(/\A(?:Shift|Dequeue)/i)
      return :last if predicate_name.match?(/\A(?:Pop|Remove|Delete|Get)/i)

      nil
    end

    # @rbs value: String
    # @rbs return: String
    def camelize(value)
      value.to_s.split(/[^a-zA-Z0-9]+/).reject(&:empty?).map { |part| part[0].upcase + part[1..] }.join
    end
  end
end
