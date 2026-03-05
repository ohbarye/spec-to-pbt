# frozen_string_literal: true

# rbs_inline: enabled

module SpecToPbt
  StatefulPredicateAnalysis = Data.define(
    :predicate_name,
    :state_param_names,
    :state_type,
    :argument_params,
    :state_field,
    :state_field_multiplicity,
    :size_delta,
    :requires_non_empty_state,
    :transition_kind,
    :result_position,
    :scalar_update_kind,
    :command_confidence
  ) do
    # @rbs predicate_name: String
    # @rbs state_param_names: Array[String]
    # @rbs state_type: String?
    # @rbs argument_params: Array[Hash[Symbol, String]]
    # @rbs state_field: String?
    # @rbs state_field_multiplicity: String?
    # @rbs size_delta: Integer?
    # @rbs requires_non_empty_state: bool
    # @rbs transition_kind: Symbol?
    # @rbs result_position: Symbol?
    # @rbs scalar_update_kind: Symbol?
    # @rbs command_confidence: Symbol
    # @rbs return: void
    def initialize(predicate_name:, state_param_names: [], state_type: nil, argument_params: [], state_field: nil, state_field_multiplicity: nil, size_delta: nil, requires_non_empty_state: false, transition_kind: nil, result_position: nil, scalar_update_kind: nil, command_confidence: :low) = super
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
      state_field_multiplicity = infer_state_field_multiplicity(state_type, state_field)
      size_delta = infer_size_delta(predicate.body)
      requires_non_empty_state = requires_non_empty_state?(predicate.body)

      transition_kind = infer_transition_kind(predicate.name, predicate.body, size_delta, requires_non_empty_state)
      scalar_update_kind = infer_scalar_update_kind(predicate.body, state_field, state_field_multiplicity)

      StatefulPredicateAnalysis.new(
        predicate_name: predicate.name,
        state_param_names:,
        state_type:,
        argument_params:,
        state_field:,
        state_field_multiplicity:,
        size_delta:,
        requires_non_empty_state:,
        transition_kind:,
        result_position: infer_result_position(predicate.name, transition_kind),
        scalar_update_kind:,
        command_confidence: infer_command_confidence(predicate.name, transition_kind, size_delta, requires_non_empty_state, scalar_update_kind)
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
      return 1 if body.match?(/#\w+'?\.\w+\s*=\s*(?:add\[|#\w+\.?\w*\s*\+\s*1)/)
      return -1 if body.match?(/#\w+'?\.\w+\s*=\s*(?:sub\[|#\w+\.?\w*\s*-\s*1)/)
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

    # @rbs state_type: String?
    # @rbs state_field: String?
    # @rbs return: String?
    def infer_state_field_multiplicity(state_type, state_field)
      return nil unless state_type && state_field

      signature = @spec.signatures.find { |sig| sig.name == state_type }
      return nil unless signature

      field = signature.fields.find { |item| item.name == state_field }
      field&.multiplicity
    end

    # @rbs body: String
    # @rbs return: bool
    def requires_non_empty_state?(body)
      body.match?(/#\w+\.?\w*\s*(?:>\s*0|>=\s*1)/)
    end

    # @rbs predicate_name: String
    # @rbs body: String
    # @rbs size_delta: Integer?
    # @rbs requires_non_empty_state: bool
    # @rbs return: Symbol?
    def infer_transition_kind(predicate_name, body, size_delta, requires_non_empty_state)
      return :append if size_delta == 1
      if size_delta == -1
        return :dequeue if dequeue_like_text?(predicate_name, body)
        return :pop if pop_like_text?(predicate_name, body)
        return :pop if requires_non_empty_state
      end
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

    # @rbs body: String
    # @rbs state_field: String?
    # @rbs state_field_multiplicity: String?
    # @rbs return: Symbol?
    def infer_scalar_update_kind(body, state_field, state_field_multiplicity)
      return nil if state_field.nil?
      return nil if ["seq", "set"].include?(state_field_multiplicity)

      return :increment_like if body.match?(/#\w+'?\.#{Regexp.escape(state_field)}\s*=\s*(?:add\[|#\w+\.?#{Regexp.escape(state_field)}\s*\+\s*1)/)
      return :decrement_like if body.match?(/#\w+'?\.#{Regexp.escape(state_field)}\s*=\s*(?:sub\[|#\w+\.?#{Regexp.escape(state_field)}\s*-\s*1)/)
      return :replace_like if body.match?(/#\w+'?\.#{Regexp.escape(state_field)}\s*=\s*#?\w+/)

      nil
    end

    # @rbs predicate_name: String
    # @rbs transition_kind: Symbol?
    # @rbs size_delta: Integer?
    # @rbs requires_non_empty_state: bool
    # @rbs scalar_update_kind: Symbol?
    # @rbs return: Symbol
    def infer_command_confidence(predicate_name, transition_kind, size_delta, requires_non_empty_state, scalar_update_kind)
      return :high if predicate_name.match?(/\A(?:Push|Pop|Enqueue|Dequeue|Add|Remove|Insert|Delete|Put|Get)/)
      return :high if [:append, :pop, :dequeue].include?(transition_kind)
      return :medium if transition_kind == :size_no_change
      return :medium if !scalar_update_kind.nil?
      return :medium if !size_delta.nil? || requires_non_empty_state

      :low
    end

    # @rbs predicate_name: String
    # @rbs body: String
    # @rbs return: bool
    def dequeue_like_text?(predicate_name, body)
      text = "#{predicate_name} #{body}"
      text.match?(/(?:dequeue|shift|front|head|first)/i)
    end

    # @rbs predicate_name: String
    # @rbs body: String
    # @rbs return: bool
    def pop_like_text?(predicate_name, body)
      text = "#{predicate_name} #{body}"
      text.match?(/(?:pop|drop.*last|remove.*last|tail|back|end|last)/i)
    end

    # @rbs value: String
    # @rbs return: String
    def camelize(value)
      value.to_s.split(/[^a-zA-Z0-9]+/).reject(&:empty?).map { |part| part[0].upcase + part[1..] }.join
    end
  end
end
