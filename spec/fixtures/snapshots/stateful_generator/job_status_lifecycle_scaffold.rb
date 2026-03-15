# frozen_string_literal: true

require "pbt"
require "rspec"
require_relative "job_status_lifecycle_impl"
require_relative "job_status_lifecycle_pbt_config" if File.exist?(File.expand_path("job_status_lifecycle_pbt_config.rb", __dir__))

if File.exist?(File.expand_path("job_status_lifecycle_pbt_config.rb", __dir__)) && !defined?(::JobStatusLifecyclePbtConfig)
  raise "Expected JobStatusLifecyclePbtConfig to be defined in job_status_lifecycle_pbt_config.rb"
end

unless Pbt.respond_to?(:stateful)
  loaded_pbt_version = defined?(Gem.loaded_specs) ? Gem.loaded_specs["pbt"]&.version&.to_s : nil
  detail = loaded_pbt_version ? "loaded pbt #{loaded_pbt_version}" : "loaded pbt version unknown"
  raise "Expected pbt >= 0.5.1 with Pbt.stateful (#{detail}). Install a compatible pbt release before running this scaffold."
end

RSpec.describe "job_status_lifecycle (stateful scaffold)" do
  # Regeneration-safe customization:
  # - edit job_status_lifecycle_pbt_config.rb for SUT wiring and durable API mapping
  # - edit job_status_lifecycle_impl.rb for implementation behavior
  # - edit this scaffold only for one-off refinements when needed

  module JobStatusLifecyclePbtSupport
    module_function
    ARGUMENTS_OVERRIDE_UNSET = Object.new.freeze

    def config
      defined?(::JobStatusLifecyclePbtConfig) ? ::JobStatusLifecyclePbtConfig : {}
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

  it "wires a stateful PBT scaffold (customize before enabling)" do
    unless ENV["ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD"] == "1"
      skip "Set ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 after customizing the generated scaffold"
    end

    Pbt.assert(worker: :none, num_runs: 5, seed: 1) do
      Pbt.stateful(
        model: JobStatusLifecycleModel.new,
        sut: -> { JobStatusLifecyclePbtSupport.sut_factory(-> { JobStatusLifecycleImpl.new }).call },
        max_steps: 20
      )
    end
  end

  class JobStatusLifecycleModel
    def initialize
      @commands = [
        StartCommand.new,
        CompleteCommand.new,
        FailCommand.new,
        DeadLetterCommand.new
      ]
    end

    def initial_state
      default_state = 0 # TODO: replace with a domain-specific scalar model state
      JobStatusLifecyclePbtSupport.initial_state(default_state)
    end

    def commands(_state)
      @commands
    end
  end

  class StartCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :start
    end

    def arguments
      overridden = JobStatusLifecyclePbtSupport.call_arguments_override(name)
      return overridden unless overridden.equal?(JobStatusLifecyclePbtSupport::ARGUMENTS_OVERRIDE_UNSET)
      Pbt.nil
    end

    def applicable?(state)
      override = JobStatusLifecyclePbtSupport.applicable_override(name)
      return JobStatusLifecyclePbtSupport.call_applicable_override(override, state, nil) if override
      return true if JobStatusLifecyclePbtSupport.guard_failure_policy(name)
      guard_satisfied?(state)
    end

    def guard_satisfied?(state, _args = nil)
      state == 0 # inferred scalar lifecycle/status precondition for start
    end

    def next_state(state, args)
      override = JobStatusLifecyclePbtSupport.next_state_override(name)
      return JobStatusLifecyclePbtSupport.call_next_state_override(override, state, args) if override
      return state if JobStatusLifecyclePbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      1
    end

    def run!(sut, args)
      JobStatusLifecyclePbtSupport.before_run_hook&.call(sut)
      payload = JobStatusLifecyclePbtSupport.adapt_args(name, args)
      method_name = JobStatusLifecyclePbtSupport.resolve_method_name(name, :start)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(JobStatusLifecyclePbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = JobStatusLifecyclePbtSupport.adapt_result(name, result)
      JobStatusLifecyclePbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#j.status=0 implies#j'.status=1"
      # Analyzer hints: state_field="status", size_delta=nil, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:replace_like, command_confidence=:medium, guard_kind=:state_equals_constant, guard_field="status", guard_constant="0", rhs_source_kind=:constant, state_update_shape=:replace_constant
      # Related Alloy property predicates: Complete, Fail, DeadLetter
      # Related pattern hints: size
      # Derived verify hints: check_size_semantics, check_guard_failure_semantics
      policy = JobStatusLifecyclePbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if JobStatusLifecyclePbtSupport.call_verify_override(
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
        observed = JobStatusLifecyclePbtSupport.observed_state(sut)
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
      observed = JobStatusLifecyclePbtSupport.observed_state(sut)
      if !observed.nil?
        expected_observed_state = after_state
        raise "Expected observed state to match model" unless observed == expected_observed_state
      end
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Job#status
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      expected = 1
      raise "Expected replaced value for Job#status" unless after_state == expected
      [sut, args] && nil
    end
  end

  class CompleteCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :complete
    end

    def arguments
      overridden = JobStatusLifecyclePbtSupport.call_arguments_override(name)
      return overridden unless overridden.equal?(JobStatusLifecyclePbtSupport::ARGUMENTS_OVERRIDE_UNSET)
      Pbt.nil
    end

    def applicable?(state)
      override = JobStatusLifecyclePbtSupport.applicable_override(name)
      return JobStatusLifecyclePbtSupport.call_applicable_override(override, state, nil) if override
      return true if JobStatusLifecyclePbtSupport.guard_failure_policy(name)
      guard_satisfied?(state)
    end

    def guard_satisfied?(state, _args = nil)
      state == 1 # inferred scalar lifecycle/status precondition for complete
    end

    def next_state(state, args)
      override = JobStatusLifecyclePbtSupport.next_state_override(name)
      return JobStatusLifecyclePbtSupport.call_next_state_override(override, state, args) if override
      return state if JobStatusLifecyclePbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      2
    end

    def run!(sut, args)
      JobStatusLifecyclePbtSupport.before_run_hook&.call(sut)
      payload = JobStatusLifecyclePbtSupport.adapt_args(name, args)
      method_name = JobStatusLifecyclePbtSupport.resolve_method_name(name, :complete)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(JobStatusLifecyclePbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = JobStatusLifecyclePbtSupport.adapt_result(name, result)
      JobStatusLifecyclePbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#j.status=1 implies#j'.status=2"
      # Analyzer hints: state_field="status", size_delta=nil, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:replace_like, command_confidence=:medium, guard_kind=:state_equals_constant, guard_field="status", guard_constant="1", rhs_source_kind=:constant, state_update_shape=:replace_constant
      # Related Alloy property predicates: Start, Fail, DeadLetter
      # Related pattern hints: size
      # Derived verify hints: check_size_semantics, check_guard_failure_semantics
      policy = JobStatusLifecyclePbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if JobStatusLifecyclePbtSupport.call_verify_override(
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
        observed = JobStatusLifecyclePbtSupport.observed_state(sut)
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
      observed = JobStatusLifecyclePbtSupport.observed_state(sut)
      if !observed.nil?
        expected_observed_state = after_state
        raise "Expected observed state to match model" unless observed == expected_observed_state
      end
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Job#status
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      expected = 2
      raise "Expected replaced value for Job#status" unless after_state == expected
      [sut, args] && nil
    end
  end

  class FailCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :fail
    end

    def arguments
      overridden = JobStatusLifecyclePbtSupport.call_arguments_override(name)
      return overridden unless overridden.equal?(JobStatusLifecyclePbtSupport::ARGUMENTS_OVERRIDE_UNSET)
      Pbt.nil
    end

    def applicable?(state)
      override = JobStatusLifecyclePbtSupport.applicable_override(name)
      return JobStatusLifecyclePbtSupport.call_applicable_override(override, state, nil) if override
      return true if JobStatusLifecyclePbtSupport.guard_failure_policy(name)
      guard_satisfied?(state)
    end

    def guard_satisfied?(state, _args = nil)
      state == 1 # inferred scalar lifecycle/status precondition for fail
    end

    def next_state(state, args)
      override = JobStatusLifecyclePbtSupport.next_state_override(name)
      return JobStatusLifecyclePbtSupport.call_next_state_override(override, state, args) if override
      return state if JobStatusLifecyclePbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      3
    end

    def run!(sut, args)
      JobStatusLifecyclePbtSupport.before_run_hook&.call(sut)
      payload = JobStatusLifecyclePbtSupport.adapt_args(name, args)
      method_name = JobStatusLifecyclePbtSupport.resolve_method_name(name, :fail)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(JobStatusLifecyclePbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = JobStatusLifecyclePbtSupport.adapt_result(name, result)
      JobStatusLifecyclePbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#j.status=1 implies#j'.status=3"
      # Analyzer hints: state_field="status", size_delta=nil, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:replace_like, command_confidence=:medium, guard_kind=:state_equals_constant, guard_field="status", guard_constant="1", rhs_source_kind=:constant, state_update_shape=:replace_constant
      # Related Alloy property predicates: Start, Complete, DeadLetter
      # Related pattern hints: size
      # Derived verify hints: check_size_semantics, check_guard_failure_semantics
      policy = JobStatusLifecyclePbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if JobStatusLifecyclePbtSupport.call_verify_override(
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
        observed = JobStatusLifecyclePbtSupport.observed_state(sut)
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
      observed = JobStatusLifecyclePbtSupport.observed_state(sut)
      if !observed.nil?
        expected_observed_state = after_state
        raise "Expected observed state to match model" unless observed == expected_observed_state
      end
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Job#status
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      expected = 3
      raise "Expected replaced value for Job#status" unless after_state == expected
      [sut, args] && nil
    end
  end

  class DeadLetterCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :dead_letter
    end

    def arguments
      overridden = JobStatusLifecyclePbtSupport.call_arguments_override(name)
      return overridden unless overridden.equal?(JobStatusLifecyclePbtSupport::ARGUMENTS_OVERRIDE_UNSET)
      Pbt.nil
    end

    def applicable?(state)
      override = JobStatusLifecyclePbtSupport.applicable_override(name)
      return JobStatusLifecyclePbtSupport.call_applicable_override(override, state, nil) if override
      return true if JobStatusLifecyclePbtSupport.guard_failure_policy(name)
      guard_satisfied?(state)
    end

    def guard_satisfied?(state, _args = nil)
      state == 3 # inferred scalar lifecycle/status precondition for dead_letter
    end

    def next_state(state, args)
      override = JobStatusLifecyclePbtSupport.next_state_override(name)
      return JobStatusLifecyclePbtSupport.call_next_state_override(override, state, args) if override
      return state if JobStatusLifecyclePbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      4
    end

    def run!(sut, args)
      JobStatusLifecyclePbtSupport.before_run_hook&.call(sut)
      payload = JobStatusLifecyclePbtSupport.adapt_args(name, args)
      method_name = JobStatusLifecyclePbtSupport.resolve_method_name(name, :dead_letter)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(JobStatusLifecyclePbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = JobStatusLifecyclePbtSupport.adapt_result(name, result)
      JobStatusLifecyclePbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#j.status=3 implies#j'.status=4"
      # Analyzer hints: state_field="status", size_delta=nil, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:replace_like, command_confidence=:medium, guard_kind=:state_equals_constant, guard_field="status", guard_constant="3", rhs_source_kind=:constant, state_update_shape=:replace_constant
      # Related Alloy property predicates: Start, Complete, Fail
      # Related pattern hints: size
      # Derived verify hints: check_size_semantics, check_guard_failure_semantics
      policy = JobStatusLifecyclePbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if JobStatusLifecyclePbtSupport.call_verify_override(
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
        observed = JobStatusLifecyclePbtSupport.observed_state(sut)
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
      observed = JobStatusLifecyclePbtSupport.observed_state(sut)
      if !observed.nil?
        expected_observed_state = after_state
        raise "Expected observed state to match model" unless observed == expected_observed_state
      end
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Job#status
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      expected = 4
      raise "Expected replaced value for Job#status" unless after_state == expected
      [sut, args] && nil
    end
  end

end