# frozen_string_literal: true

# rbs_inline: enabled

module SpecToPbt
  StatefulPredicateAnalysis = Data.define(
    :predicate_name,
    :state_param_names,
    :state_type,
    :argument_params,
    :size_delta,
    :requires_non_empty_state
  ) do
    # @rbs predicate_name: String
    # @rbs state_param_names: Array[String]
    # @rbs state_type: String?
    # @rbs argument_params: Array[Hash[Symbol, String]]
    # @rbs size_delta: Integer?
    # @rbs requires_non_empty_state: bool
    # @rbs return: void
    def initialize(predicate_name:, state_param_names: [], state_type: nil, argument_params: [], size_delta: nil, requires_non_empty_state: false) = super
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

      StatefulPredicateAnalysis.new(
        predicate_name: predicate.name,
        state_param_names:,
        state_type:,
        argument_params:,
        size_delta: infer_size_delta(predicate.body),
        requires_non_empty_state: requires_non_empty_state?(predicate.body)
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
    # @rbs return: bool
    def requires_non_empty_state?(body)
      body.match?(/#\w+\.?\w*\s*>\s*0/)
    end

    # @rbs value: String
    # @rbs return: String
    def camelize(value)
      value.to_s.split(/[^a-zA-Z0-9]+/).reject(&:empty?).map { |part| part[0].upcase + part[1..] }.join
    end
  end
end
