# frozen_string_literal: true

require "pbt"
require_relative "hold_capture_release_impl" if File.exist?(File.expand_path("hold_capture_release_impl.rb", __dir__))
require_relative "hold_capture_release_pbt_config" if File.exist?(File.expand_path("hold_capture_release_pbt_config.rb", __dir__))

if File.exist?(File.expand_path("hold_capture_release_pbt_config.rb", __dir__)) && !defined?(::HoldCaptureReleasePbtConfig)
  raise "Expected HoldCaptureReleasePbtConfig to be defined in hold_capture_release_pbt_config.rb"
end

unless Pbt.respond_to?(:stateful)
  loaded_pbt_version = defined?(Gem.loaded_specs) ? Gem.loaded_specs["pbt"]&.version&.to_s : nil
  detail = loaded_pbt_version ? "loaded pbt #{loaded_pbt_version}" : "loaded pbt version unknown"
  raise "Expected pbt >= 0.6.0 with Pbt.stateful (#{detail}). Install a compatible pbt release before running this scaffold."
end

RSpec.describe "hold_capture_release (stateful scaffold)" do
  # Regeneration-safe customization:
  # - edit hold_capture_release_pbt_config.rb for SUT wiring and durable API mapping
  # - edit hold_capture_release_impl.rb for implementation behavior
  # - edit this scaffold only for one-off refinements when needed

  module HoldCaptureReleasePbtSupport
    module_function
    ARGUMENTS_OVERRIDE_UNSET = Object.new.freeze

    KNOWN_TOP_LEVEL_KEYS = %i[sut_factory initial_state command_mappings verify_context before_run after_run state_reader].freeze
    KNOWN_COMMAND_KEYS = %i[method arg_adapter model_arg_adapter result_adapter arguments_override applicable_override next_state_override verify_override guard_failure_policy].freeze

    def config
      defined?(::HoldCaptureReleasePbtConfig) ? ::HoldCaptureReleasePbtConfig : {}
    end

    def validate_config!
      return if config.empty?

      unknown_top = config.keys - KNOWN_TOP_LEVEL_KEYS
      raise "Unknown config keys in HoldCaptureReleasePbtConfig: #{unknown_top.inspect}. See docs/config-reference.md for valid keys." unless unknown_top.empty?

      config.fetch(:command_mappings, {}).each do |cmd_name, cmd_config|
        next unless cmd_config.is_a?(Hash)
        unknown_cmd = cmd_config.keys - KNOWN_COMMAND_KEYS
        raise "Unknown config keys in HoldCaptureReleasePbtConfig command_mappings[#{cmd_name}]: #{unknown_cmd.inspect}. See docs/config-reference.md for valid keys." unless unknown_cmd.empty?
      end

      if !config.key?(:sut_factory)
        warn "Warning: HoldCaptureReleasePbtConfig is missing :sut_factory (required). The scaffold will use a default factory."
      end

      if state_reader.nil?
        warn "Warning: HoldCaptureReleasePbtConfig has no verify_context.state_reader configured. SUT state will not be compared against the model."
      end
    end

    def sut_factory(default_factory)
      config.fetch(:sut_factory, default_factory)
    end

    def initial_state(default_state)
      config.fetch(:initial_state, default_state)
    end

    def command_config(command_name)
      config.fetch(:command_mappings, {}).fetch(command_name, {})
    end

    def arguments_override(command_name)
      command_config(command_name)[:arguments_override]
    end

    def call_arguments_override(command_name, state = ARGUMENTS_OVERRIDE_UNSET)
      override = arguments_override(command_name)
      return ARGUMENTS_OVERRIDE_UNSET unless override

      parameters = override.parameters
      if parameters.any? { |kind, _name| kind == :rest }
        return state.equal?(ARGUMENTS_OVERRIDE_UNSET) ? override.call : override.call(state)
      end

      required = parameters.count { |kind, _name| kind == :req }
      optional = parameters.count { |kind, _name| kind == :opt }
      provided = state.equal?(ARGUMENTS_OVERRIDE_UNSET) ? 0 : 1

      if provided >= required && provided <= required + optional
        return provided.zero? ? override.call : override.call(state)
      end

      if 0 >= required && 0 <= required + optional
        return override.call
      end

      raise ArgumentError, "arguments_override for command #{command_name.inspect} must accept 0 or 1 positional arguments"
    end

    def resolve_method_name(command_name, default_method_name)
      command_config(command_name).fetch(:method, default_method_name)
    end

    def adapt_args(command_name, args)
      settings = command_config(command_name)
      adapter = settings[:arg_adapter] || settings[:model_arg_adapter]
      adapter ? adapter.call(args) : args
    end

    def model_args(command_name, args)
      adapter = command_config(command_name)[:model_arg_adapter] || command_config(command_name)[:arg_adapter]
      adapter ? adapter.call(args) : args
    end

    def scalar_model_arg(command_name, args)
      payload = model_args(command_name, args)
      payload.is_a?(Array) && payload.length == 1 ? payload.first : payload
    end

    def adapt_result(command_name, result)
      adapter = command_config(command_name)[:result_adapter]
      adapter ? adapter.call(result) : result
    end

    def applicable_override(command_name)
      command_config(command_name)[:applicable_override]
    end

    def next_state_override(command_name)
      command_config(command_name)[:next_state_override]
    end

    def guard_failure_policy(command_name)
      command_config(command_name)[:guard_failure_policy]
    end

    def call_applicable_override(override, state, args)
      parameters = override.parameters
      if parameters.any? { |kind, _name| kind == :rest }
        override.call(state, args)
      else
        required = parameters.count { |kind, _name| kind == :req }
        optional = parameters.count { |kind, _name| kind == :opt }
        if 2 >= required && 2 <= required + optional
          override.call(state, args)
        elsif 1 >= required && 1 <= required + optional
          override.call(state)
        else
          override.call
        end
      end
    end

    def call_next_state_override(override, state, args)
      return nil unless override

      parameters = override.parameters
      if parameters.any? { |kind, _name| kind == :rest }
        override.call(state, args)
      else
        required = parameters.count { |kind, _name| kind == :req }
        optional = parameters.count { |kind, _name| kind == :opt }
        if 2 >= required && 2 <= required + optional
          override.call(state, args)
        elsif 1 >= required && 1 <= required + optional
          override.call(state)
        else
          override.call
        end
      end
    end

    def verify_override(command_name)
      command_config(command_name)[:verify_override]
    end

    def state_reader
      config.fetch(:verify_context, {})[:state_reader] || config[:state_reader]
    end

    def observed_state(sut)
      reader = state_reader
      reader ? reader.call(sut) : nil
    end

    def call_verify_override(command_name, **kwargs)
      override = verify_override(command_name)
      return false unless override

      payload = kwargs.merge(observed_state: observed_state(kwargs[:sut]))
      if override.parameters.any? { |kind, _name| kind == :keyrest }
        override.call(**payload)
      else
        accepted = override.parameters.filter_map do |kind, name|
          name if [:keyreq, :key].include?(kind)
        end
        accepted_payload = accepted.empty? ? {} : payload.select { |key, _value| accepted.include?(key) }
        override.call(**accepted_payload)
      end
      true
    end

    def before_run_hook
      config[:before_run]
    end

    def after_run_hook
      config[:after_run]
    end
  end

  it "wires a stateful PBT scaffold" do
    HoldCaptureReleasePbtSupport.validate_config!

    Pbt.assert(worker: :none, num_runs: 5, seed: 1) do
      Pbt.stateful(
        model: HoldCaptureReleaseModel.new,
        sut: -> { HoldCaptureReleasePbtSupport.sut_factory(-> { HoldCaptureReleaseImpl.new }).call },
        max_steps: 20
      )
    end
  end

  class HoldCaptureReleaseModel
    def initialize
      @commands = [
        HoldCommand.new,
        CaptureCommand.new,
        ReleaseCommand.new
      ]
    end

    def initial_state
      default_state = { available: 0, held: 0 } # TODO: replace with a domain-specific structured model state
      HoldCaptureReleasePbtSupport.initial_state(default_state)
    end

    def commands(_state)
      @commands
    end
  end

  class HoldCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :hold
    end

    def arguments(state)
      overridden = HoldCaptureReleasePbtSupport.call_arguments_override(name, state)
      return overridden unless overridden.equal?(HoldCaptureReleasePbtSupport::ARGUMENTS_OVERRIDE_UNSET)
      Pbt.integer(min: 1, max: state[:available])
    end

    def applicable?(state, args)
      override = HoldCaptureReleasePbtSupport.applicable_override(name)
      return HoldCaptureReleasePbtSupport.call_applicable_override(override, state, args) if override
      return true if HoldCaptureReleasePbtSupport.guard_failure_policy(name)
      guard_satisfied?(state, args)
    end

    def guard_satisfied?(state, args = nil)
      delta = HoldCaptureReleasePbtSupport.scalar_model_arg(name, args)
      current_value = state[:available]
      delta.is_a?(Numeric) && delta.positive? && delta <= current_value
    end

    def next_state(state, args)
      override = HoldCaptureReleasePbtSupport.next_state_override(name)
      return HoldCaptureReleasePbtSupport.call_next_state_override(override, state, args) if override
      return state if HoldCaptureReleasePbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      delta = HoldCaptureReleasePbtSupport.scalar_model_arg(name, args)
      state.merge(available: state[:available] - delta, held: state[:held] + delta)
    end

    def run!(sut, args)
      HoldCaptureReleasePbtSupport.before_run_hook&.call(sut)
      payload = HoldCaptureReleasePbtSupport.adapt_args(name, args)
      method_name = HoldCaptureReleasePbtSupport.resolve_method_name(name, :hold)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(HoldCaptureReleasePbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = HoldCaptureReleasePbtSupport.adapt_result(name, result)
      HoldCaptureReleasePbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#r.available>=amount implies#r'.available=sub[#r.available,amount]and#r'.held=add[#r.held,amount]"
      # Analyzer hints: state_field="available", size_delta=1, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:decrement_like, command_confidence=:medium, guard_kind=:arg_within_state, guard_field="available", guard_constant=nil, rhs_source_kind=:arg, state_update_shape=:decrement
      # Related Alloy property predicates: Capture, Release, NonNegativeAvailable
      # Related pattern hints: size
      # Derived verify hints: check_size_semantics, check_non_negative_scalar_state, check_guard_failure_semantics
      policy = HoldCaptureReleasePbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if HoldCaptureReleasePbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut,
        guard_failed: guard_failed,
        guard_failure_policy: policy
      )
      raise result if result.is_a?(StandardError) && !guard_failed
      if guard_failed
        observed = HoldCaptureReleasePbtSupport.observed_state(sut)
        case policy
        when :no_op
          raise "Expected unchanged model state on guard failure" unless after_state == before_state
          raise "Expected unchanged observed state on guard failure" if !observed.nil? && observed != after_state
        when :raise
          raise "Expected guard failure to surface as an exception" unless result.is_a?(StandardError)
          raise "Expected unchanged model state on guard failure" unless after_state == before_state
          raise "Expected unchanged observed state on guard failure" if !observed.nil? && observed != after_state
        when :custom
          raise "guard_failure_policy :custom requires verify_override to assert invalid-path semantics"
        else
          raise "Unsupported guard_failure_policy: #{policy.inspect}"
        end
        return nil
      end
      observed = HoldCaptureReleasePbtSupport.observed_state(sut)
      if !observed.nil?
        expected_observed_state = after_state
        raise "Expected observed state to match model" unless observed == expected_observed_state
      end
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Reservation#available
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from related assertions/facts: keep non-negative scalar invariants aligned with the model state
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      delta = HoldCaptureReleasePbtSupport.scalar_model_arg(name, args)
      before_available = before_state[:available]
      after_available = after_state[:available]
      raise "Expected sufficient scalar state before decrement" unless delta <= before_state[:available]
      raise "Expected decremented value for Reservation#available" unless after_available == before_available - delta
      raise "Expected non-negative value for Reservation#available" unless after_available >= 0
      before_held = before_state[:held]
      after_held = after_state[:held]
      raise "Expected incremented value for Reservation#held" unless after_held == before_held + delta
      raise "Expected non-negative value for Reservation#held" unless after_held >= 0
      raise "Expected total scalar value to stay the same" unless after_available + after_held == before_available + before_held
      [sut, args] && nil
    end
  end

  class CaptureCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :capture
    end

    def arguments(state)
      overridden = HoldCaptureReleasePbtSupport.call_arguments_override(name, state)
      return overridden unless overridden.equal?(HoldCaptureReleasePbtSupport::ARGUMENTS_OVERRIDE_UNSET)
      Pbt.integer(min: 1, max: state[:held])
    end

    def applicable?(state, args)
      override = HoldCaptureReleasePbtSupport.applicable_override(name)
      return HoldCaptureReleasePbtSupport.call_applicable_override(override, state, args) if override
      return true if HoldCaptureReleasePbtSupport.guard_failure_policy(name)
      guard_satisfied?(state, args)
    end

    def guard_satisfied?(state, args = nil)
      delta = HoldCaptureReleasePbtSupport.scalar_model_arg(name, args)
      current_value = state[:held]
      delta.is_a?(Numeric) && delta.positive? && delta <= current_value
    end

    def next_state(state, args)
      override = HoldCaptureReleasePbtSupport.next_state_override(name)
      return HoldCaptureReleasePbtSupport.call_next_state_override(override, state, args) if override
      return state if HoldCaptureReleasePbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      delta = HoldCaptureReleasePbtSupport.scalar_model_arg(name, args)
      state.merge(held: state[:held] - delta)
    end

    def run!(sut, args)
      HoldCaptureReleasePbtSupport.before_run_hook&.call(sut)
      payload = HoldCaptureReleasePbtSupport.adapt_args(name, args)
      method_name = HoldCaptureReleasePbtSupport.resolve_method_name(name, :capture)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(HoldCaptureReleasePbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = HoldCaptureReleasePbtSupport.adapt_result(name, result)
      HoldCaptureReleasePbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#r.held>=amount implies#r'.held=sub[#r.held,amount]"
      # Analyzer hints: state_field="held", size_delta=-1, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:decrement_like, command_confidence=:medium, guard_kind=:arg_within_state, guard_field="held", guard_constant=nil, rhs_source_kind=:arg, state_update_shape=:decrement
      # Related Alloy property predicates: Hold, Release, NonNegativeHeld
      # Related pattern hints: size
      # Derived verify hints: check_size_semantics, check_non_negative_scalar_state, check_guard_failure_semantics
      policy = HoldCaptureReleasePbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if HoldCaptureReleasePbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut,
        guard_failed: guard_failed,
        guard_failure_policy: policy
      )
      raise result if result.is_a?(StandardError) && !guard_failed
      if guard_failed
        observed = HoldCaptureReleasePbtSupport.observed_state(sut)
        case policy
        when :no_op
          raise "Expected unchanged model state on guard failure" unless after_state == before_state
          raise "Expected unchanged observed state on guard failure" if !observed.nil? && observed != after_state
        when :raise
          raise "Expected guard failure to surface as an exception" unless result.is_a?(StandardError)
          raise "Expected unchanged model state on guard failure" unless after_state == before_state
          raise "Expected unchanged observed state on guard failure" if !observed.nil? && observed != after_state
        when :custom
          raise "guard_failure_policy :custom requires verify_override to assert invalid-path semantics"
        else
          raise "Unsupported guard_failure_policy: #{policy.inspect}"
        end
        return nil
      end
      observed = HoldCaptureReleasePbtSupport.observed_state(sut)
      if !observed.nil?
        expected_observed_state = after_state
        raise "Expected observed state to match model" unless observed == expected_observed_state
      end
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Reservation#held
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from related assertions/facts: keep non-negative scalar invariants aligned with the model state
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      delta = HoldCaptureReleasePbtSupport.scalar_model_arg(name, args)
      raise "Expected sufficient scalar state before decrement" unless delta <= before_state[:held]
      before_value = before_state[:held]
      after_value = after_state[:held]
      raise "Expected decremented value for Reservation#held" unless after_value == before_value - delta
      raise "Expected non-negative value for Reservation#held" unless after_state[:held] >= 0
      [sut, args] && nil
    end
  end

  class ReleaseCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :release
    end

    def arguments(state)
      overridden = HoldCaptureReleasePbtSupport.call_arguments_override(name, state)
      return overridden unless overridden.equal?(HoldCaptureReleasePbtSupport::ARGUMENTS_OVERRIDE_UNSET)
      Pbt.integer(min: 1, max: state[:held])
    end

    def applicable?(state, args)
      override = HoldCaptureReleasePbtSupport.applicable_override(name)
      return HoldCaptureReleasePbtSupport.call_applicable_override(override, state, args) if override
      return true if HoldCaptureReleasePbtSupport.guard_failure_policy(name)
      guard_satisfied?(state, args)
    end

    def guard_satisfied?(state, args = nil)
      delta = HoldCaptureReleasePbtSupport.scalar_model_arg(name, args)
      current_value = state[:held]
      delta.is_a?(Numeric) && delta.positive? && delta <= current_value
    end

    def next_state(state, args)
      override = HoldCaptureReleasePbtSupport.next_state_override(name)
      return HoldCaptureReleasePbtSupport.call_next_state_override(override, state, args) if override
      return state if HoldCaptureReleasePbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      delta = HoldCaptureReleasePbtSupport.scalar_model_arg(name, args)
      state.merge(available: state[:available] + delta, held: state[:held] - delta)
    end

    def run!(sut, args)
      HoldCaptureReleasePbtSupport.before_run_hook&.call(sut)
      payload = HoldCaptureReleasePbtSupport.adapt_args(name, args)
      method_name = HoldCaptureReleasePbtSupport.resolve_method_name(name, :release)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(HoldCaptureReleasePbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = HoldCaptureReleasePbtSupport.adapt_result(name, result)
      HoldCaptureReleasePbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#r.held>=amount implies#r'.available=add[#r.available,amount]and#r'.held=sub[#r.held,amount]"
      # Analyzer hints: state_field="held", size_delta=1, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:decrement_like, command_confidence=:medium, guard_kind=:arg_within_state, guard_field="held", guard_constant=nil, rhs_source_kind=:arg, state_update_shape=:decrement
      # Related Alloy property predicates: Hold, Capture, NonNegativeHeld
      # Related pattern hints: size
      # Derived verify hints: check_size_semantics, check_non_negative_scalar_state, check_guard_failure_semantics
      policy = HoldCaptureReleasePbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if HoldCaptureReleasePbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut,
        guard_failed: guard_failed,
        guard_failure_policy: policy
      )
      raise result if result.is_a?(StandardError) && !guard_failed
      if guard_failed
        observed = HoldCaptureReleasePbtSupport.observed_state(sut)
        case policy
        when :no_op
          raise "Expected unchanged model state on guard failure" unless after_state == before_state
          raise "Expected unchanged observed state on guard failure" if !observed.nil? && observed != after_state
        when :raise
          raise "Expected guard failure to surface as an exception" unless result.is_a?(StandardError)
          raise "Expected unchanged model state on guard failure" unless after_state == before_state
          raise "Expected unchanged observed state on guard failure" if !observed.nil? && observed != after_state
        when :custom
          raise "guard_failure_policy :custom requires verify_override to assert invalid-path semantics"
        else
          raise "Unsupported guard_failure_policy: #{policy.inspect}"
        end
        return nil
      end
      observed = HoldCaptureReleasePbtSupport.observed_state(sut)
      if !observed.nil?
        expected_observed_state = after_state
        raise "Expected observed state to match model" unless observed == expected_observed_state
      end
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Reservation#held
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from related assertions/facts: keep non-negative scalar invariants aligned with the model state
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      delta = HoldCaptureReleasePbtSupport.scalar_model_arg(name, args)
      before_available = before_state[:available]
      after_available = after_state[:available]
      raise "Expected incremented value for Reservation#available" unless after_available == before_available + delta
      raise "Expected non-negative value for Reservation#available" unless after_available >= 0
      before_held = before_state[:held]
      after_held = after_state[:held]
      raise "Expected sufficient scalar state before decrement" unless delta <= before_state[:held]
      raise "Expected decremented value for Reservation#held" unless after_held == before_held - delta
      raise "Expected non-negative value for Reservation#held" unless after_held >= 0
      raise "Expected total scalar value to stay the same" unless after_available + after_held == before_available + before_held
      [sut, args] && nil
    end
  end

end