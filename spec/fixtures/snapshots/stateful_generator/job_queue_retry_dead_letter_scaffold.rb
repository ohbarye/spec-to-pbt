# frozen_string_literal: true

require "pbt"
require "rspec"
require_relative "job_queue_retry_dead_letter_impl"
require_relative "job_queue_retry_dead_letter_pbt_config" if File.exist?(File.expand_path("job_queue_retry_dead_letter_pbt_config.rb", __dir__))

if File.exist?(File.expand_path("job_queue_retry_dead_letter_pbt_config.rb", __dir__)) && !defined?(::JobQueueRetryDeadLetterPbtConfig)
  raise "Expected JobQueueRetryDeadLetterPbtConfig to be defined in job_queue_retry_dead_letter_pbt_config.rb"
end

unless Pbt.respond_to?(:stateful)
  loaded_pbt_version = defined?(Gem.loaded_specs) ? Gem.loaded_specs["pbt"]&.version&.to_s : nil
  detail = loaded_pbt_version ? "loaded pbt #{loaded_pbt_version}" : "loaded pbt version unknown"
  raise "Expected pbt >= 0.6.0 with Pbt.stateful (#{detail}). Install a compatible pbt release before running this scaffold."
end

RSpec.describe "job_queue_retry_dead_letter (stateful scaffold)" do
  # Regeneration-safe customization:
  # - edit job_queue_retry_dead_letter_pbt_config.rb for SUT wiring and durable API mapping
  # - edit job_queue_retry_dead_letter_impl.rb for implementation behavior
  # - edit this scaffold only for one-off refinements when needed

  module JobQueueRetryDeadLetterPbtSupport
    module_function
    ARGUMENTS_OVERRIDE_UNSET = Object.new.freeze

    def config
      defined?(::JobQueueRetryDeadLetterPbtConfig) ? ::JobQueueRetryDeadLetterPbtConfig : {}
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
        model: JobQueueRetryDeadLetterModel.new,
        sut: -> { JobQueueRetryDeadLetterPbtSupport.sut_factory(-> { JobQueueRetryDeadLetterImpl.new }).call },
        max_steps: 20
      )
    end
  end

  class JobQueueRetryDeadLetterModel
    def initialize
      @commands = [
        EnqueueCommand.new,
        DispatchCommand.new,
        AckCommand.new,
        RetryCommand.new,
        DeadLetterCommand.new
      ]
    end

    def initial_state
      default_state = { ready: 0, in_flight: 0, dead_letter: 0 } # TODO: replace with a domain-specific structured model state
      JobQueueRetryDeadLetterPbtSupport.initial_state(default_state)
    end

    def commands(_state)
      @commands
    end
  end

  class EnqueueCommand
    def name
      :enqueue
    end

    def arguments
      overridden = JobQueueRetryDeadLetterPbtSupport.call_arguments_override(name)
      return overridden unless overridden.equal?(JobQueueRetryDeadLetterPbtSupport::ARGUMENTS_OVERRIDE_UNSET)
      Pbt.nil
    end

    def applicable?(state)
      override = JobQueueRetryDeadLetterPbtSupport.applicable_override(name)
      return JobQueueRetryDeadLetterPbtSupport.call_applicable_override(override, state, nil) if override
      true
    end

    def next_state(state, args)
      override = JobQueueRetryDeadLetterPbtSupport.next_state_override(name)
      return JobQueueRetryDeadLetterPbtSupport.call_next_state_override(override, state, args) if override
      state.merge(ready: state[:ready] + 1)
    end

    def run!(sut, args)
      JobQueueRetryDeadLetterPbtSupport.before_run_hook&.call(sut)
      payload = JobQueueRetryDeadLetterPbtSupport.adapt_args(name, args)
      method_name = JobQueueRetryDeadLetterPbtSupport.resolve_method_name(name, :enqueue)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(JobQueueRetryDeadLetterPbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = JobQueueRetryDeadLetterPbtSupport.adapt_result(name, result)
      JobQueueRetryDeadLetterPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#j'.ready=add[#j.ready,1]"
      # Analyzer hints: state_field="ready", size_delta=1, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:increment_like, command_confidence=:high, guard_kind=:none, guard_field="ready", guard_constant=nil, rhs_source_kind=:unknown, state_update_shape=:increment
      # Related Alloy property predicates: Dispatch, Ack, Retry, DeadLetter, NonNegativeReady
      # Related pattern hints: size
      # Derived verify hints: respect_non_empty_guard, check_size_semantics, check_non_negative_scalar_state
      policy = JobQueueRetryDeadLetterPbtSupport.guard_failure_policy(name)
      guard_failed = false
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if JobQueueRetryDeadLetterPbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut,
        guard_failed: guard_failed,
        guard_failure_policy: policy
      )
      observed = JobQueueRetryDeadLetterPbtSupport.observed_state(sut)
      if !observed.nil?
        expected_observed_state = after_state
        raise "Expected observed state to match model" unless observed == expected_observed_state
      end
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Jobs#ready
      # Derived from related assertions/facts: respect the non-empty guard before removal-style checks
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from related assertions/facts: keep non-negative scalar invariants aligned with the model state
      before_value = before_state[:ready]
      after_value = after_state[:ready]
      raise "Expected incremented value for Jobs#ready" unless after_value == before_value + 1
      raise "Expected non-negative value for Jobs#ready" unless after_state[:ready] >= 0
      [sut, args] && nil
    end
  end

  class DispatchCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :dispatch
    end

    def arguments
      overridden = JobQueueRetryDeadLetterPbtSupport.call_arguments_override(name)
      return overridden unless overridden.equal?(JobQueueRetryDeadLetterPbtSupport::ARGUMENTS_OVERRIDE_UNSET)
      Pbt.nil
    end

    def applicable?(state)
      override = JobQueueRetryDeadLetterPbtSupport.applicable_override(name)
      return JobQueueRetryDeadLetterPbtSupport.call_applicable_override(override, state, nil) if override
      return true if JobQueueRetryDeadLetterPbtSupport.guard_failure_policy(name)
      guard_satisfied?(state)
    end

    def guard_satisfied?(state, _args = nil)
      state[:ready] > 0 # inferred scalar precondition for dispatch
    end

    def next_state(state, args)
      override = JobQueueRetryDeadLetterPbtSupport.next_state_override(name)
      return JobQueueRetryDeadLetterPbtSupport.call_next_state_override(override, state, args) if override
      return state if JobQueueRetryDeadLetterPbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      state.merge(ready: state[:ready] - 1, in_flight: state[:in_flight] + 1)
    end

    def run!(sut, args)
      JobQueueRetryDeadLetterPbtSupport.before_run_hook&.call(sut)
      payload = JobQueueRetryDeadLetterPbtSupport.adapt_args(name, args)
      method_name = JobQueueRetryDeadLetterPbtSupport.resolve_method_name(name, :dispatch)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(JobQueueRetryDeadLetterPbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = JobQueueRetryDeadLetterPbtSupport.adapt_result(name, result)
      JobQueueRetryDeadLetterPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#j.ready>0 implies#j'.ready=sub[#j.ready,1]and#j'.in_flight=add[#j.in_flight,1]"
      # Analyzer hints: state_field="ready", size_delta=1, transition_kind=nil, requires_non_empty_state=true, scalar_update_kind=:decrement_like, command_confidence=:medium, guard_kind=:non_empty, guard_field="ready", guard_constant=nil, rhs_source_kind=:unknown, state_update_shape=:decrement
      # Related Alloy property predicates: Enqueue, Ack, Retry, DeadLetter, NonNegativeReady
      # Related pattern hints: size
      # Derived verify hints: respect_non_empty_guard, check_size_semantics, check_non_negative_scalar_state, check_guard_failure_semantics
      policy = JobQueueRetryDeadLetterPbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if JobQueueRetryDeadLetterPbtSupport.call_verify_override(
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
        observed = JobQueueRetryDeadLetterPbtSupport.observed_state(sut)
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
      observed = JobQueueRetryDeadLetterPbtSupport.observed_state(sut)
      if !observed.nil?
        expected_observed_state = after_state
        raise "Expected observed state to match model" unless observed == expected_observed_state
      end
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Jobs#ready
      # Derived from related assertions/facts: respect the non-empty guard before removal-style checks
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from related assertions/facts: keep non-negative scalar invariants aligned with the model state
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      before_ready = before_state[:ready]
      after_ready = after_state[:ready]
      raise "Expected decremented value for Jobs#ready" unless after_ready == before_ready - 1
      raise "Expected non-negative value for Jobs#ready" unless after_ready >= 0
      before_in_flight = before_state[:in_flight]
      after_in_flight = after_state[:in_flight]
      raise "Expected incremented value for Jobs#in_flight" unless after_in_flight == before_in_flight + 1
      raise "Expected non-negative value for Jobs#in_flight" unless after_in_flight >= 0
      raise "Expected total scalar value to stay the same" unless after_ready + after_in_flight == before_ready + before_in_flight
      [sut, args] && nil
    end
  end

  class AckCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :ack
    end

    def arguments
      overridden = JobQueueRetryDeadLetterPbtSupport.call_arguments_override(name)
      return overridden unless overridden.equal?(JobQueueRetryDeadLetterPbtSupport::ARGUMENTS_OVERRIDE_UNSET)
      Pbt.nil
    end

    def applicable?(state)
      override = JobQueueRetryDeadLetterPbtSupport.applicable_override(name)
      return JobQueueRetryDeadLetterPbtSupport.call_applicable_override(override, state, nil) if override
      return true if JobQueueRetryDeadLetterPbtSupport.guard_failure_policy(name)
      guard_satisfied?(state)
    end

    def guard_satisfied?(state, _args = nil)
      state[:in_flight] > 0 # inferred scalar precondition for ack
    end

    def next_state(state, args)
      override = JobQueueRetryDeadLetterPbtSupport.next_state_override(name)
      return JobQueueRetryDeadLetterPbtSupport.call_next_state_override(override, state, args) if override
      return state if JobQueueRetryDeadLetterPbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      state.merge(in_flight: state[:in_flight] - 1)
    end

    def run!(sut, args)
      JobQueueRetryDeadLetterPbtSupport.before_run_hook&.call(sut)
      payload = JobQueueRetryDeadLetterPbtSupport.adapt_args(name, args)
      method_name = JobQueueRetryDeadLetterPbtSupport.resolve_method_name(name, :ack)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(JobQueueRetryDeadLetterPbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = JobQueueRetryDeadLetterPbtSupport.adapt_result(name, result)
      JobQueueRetryDeadLetterPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#j.in_flight>0 implies#j'.in_flight=sub[#j.in_flight,1]"
      # Analyzer hints: state_field="in_flight", size_delta=-1, transition_kind=nil, requires_non_empty_state=true, scalar_update_kind=:decrement_like, command_confidence=:medium, guard_kind=:non_empty, guard_field="in_flight", guard_constant=nil, rhs_source_kind=:unknown, state_update_shape=:decrement
      # Related Alloy property predicates: Enqueue, Dispatch, Retry, DeadLetter
      # Related pattern hints: size
      # Derived verify hints: respect_non_empty_guard, check_size_semantics, check_guard_failure_semantics
      policy = JobQueueRetryDeadLetterPbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if JobQueueRetryDeadLetterPbtSupport.call_verify_override(
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
        observed = JobQueueRetryDeadLetterPbtSupport.observed_state(sut)
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
      observed = JobQueueRetryDeadLetterPbtSupport.observed_state(sut)
      if !observed.nil?
        expected_observed_state = after_state
        raise "Expected observed state to match model" unless observed == expected_observed_state
      end
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Jobs#in_flight
      # Derived from related assertions/facts: respect the non-empty guard before removal-style checks
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      before_value = before_state[:in_flight]
      after_value = after_state[:in_flight]
      raise "Expected decremented value for Jobs#in_flight" unless after_value == before_value - 1
      [sut, args] && nil
    end
  end

  class RetryCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :retry
    end

    def arguments
      overridden = JobQueueRetryDeadLetterPbtSupport.call_arguments_override(name)
      return overridden unless overridden.equal?(JobQueueRetryDeadLetterPbtSupport::ARGUMENTS_OVERRIDE_UNSET)
      Pbt.nil
    end

    def applicable?(state)
      override = JobQueueRetryDeadLetterPbtSupport.applicable_override(name)
      return JobQueueRetryDeadLetterPbtSupport.call_applicable_override(override, state, nil) if override
      return true if JobQueueRetryDeadLetterPbtSupport.guard_failure_policy(name)
      guard_satisfied?(state)
    end

    def guard_satisfied?(state, _args = nil)
      state[:in_flight] > 0 # inferred scalar precondition for retry
    end

    def next_state(state, args)
      override = JobQueueRetryDeadLetterPbtSupport.next_state_override(name)
      return JobQueueRetryDeadLetterPbtSupport.call_next_state_override(override, state, args) if override
      return state if JobQueueRetryDeadLetterPbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      state.merge(ready: state[:ready] + 1, in_flight: state[:in_flight] - 1)
    end

    def run!(sut, args)
      JobQueueRetryDeadLetterPbtSupport.before_run_hook&.call(sut)
      payload = JobQueueRetryDeadLetterPbtSupport.adapt_args(name, args)
      method_name = JobQueueRetryDeadLetterPbtSupport.resolve_method_name(name, :retry)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(JobQueueRetryDeadLetterPbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = JobQueueRetryDeadLetterPbtSupport.adapt_result(name, result)
      JobQueueRetryDeadLetterPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#j.in_flight>0 implies#j'.ready=add[#j.ready,1]and#j'.in_flight=sub[#j.in_flight,1]"
      # Analyzer hints: state_field="in_flight", size_delta=1, transition_kind=nil, requires_non_empty_state=true, scalar_update_kind=:decrement_like, command_confidence=:medium, guard_kind=:non_empty, guard_field="in_flight", guard_constant=nil, rhs_source_kind=:unknown, state_update_shape=:decrement
      # Related Alloy property predicates: Enqueue, Dispatch, Ack, DeadLetter
      # Related pattern hints: size
      # Derived verify hints: respect_non_empty_guard, check_size_semantics, check_guard_failure_semantics
      policy = JobQueueRetryDeadLetterPbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if JobQueueRetryDeadLetterPbtSupport.call_verify_override(
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
        observed = JobQueueRetryDeadLetterPbtSupport.observed_state(sut)
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
      observed = JobQueueRetryDeadLetterPbtSupport.observed_state(sut)
      if !observed.nil?
        expected_observed_state = after_state
        raise "Expected observed state to match model" unless observed == expected_observed_state
      end
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Jobs#in_flight
      # Derived from related assertions/facts: respect the non-empty guard before removal-style checks
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      before_ready = before_state[:ready]
      after_ready = after_state[:ready]
      raise "Expected incremented value for Jobs#ready" unless after_ready == before_ready + 1
      before_in_flight = before_state[:in_flight]
      after_in_flight = after_state[:in_flight]
      raise "Expected decremented value for Jobs#in_flight" unless after_in_flight == before_in_flight - 1
      raise "Expected total scalar value to stay the same" unless after_ready + after_in_flight == before_ready + before_in_flight
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
      overridden = JobQueueRetryDeadLetterPbtSupport.call_arguments_override(name)
      return overridden unless overridden.equal?(JobQueueRetryDeadLetterPbtSupport::ARGUMENTS_OVERRIDE_UNSET)
      Pbt.nil
    end

    def applicable?(state)
      override = JobQueueRetryDeadLetterPbtSupport.applicable_override(name)
      return JobQueueRetryDeadLetterPbtSupport.call_applicable_override(override, state, nil) if override
      return true if JobQueueRetryDeadLetterPbtSupport.guard_failure_policy(name)
      guard_satisfied?(state)
    end

    def guard_satisfied?(state, _args = nil)
      state[:in_flight] > 0 # inferred scalar precondition for dead_letter
    end

    def next_state(state, args)
      override = JobQueueRetryDeadLetterPbtSupport.next_state_override(name)
      return JobQueueRetryDeadLetterPbtSupport.call_next_state_override(override, state, args) if override
      return state if JobQueueRetryDeadLetterPbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      state.merge(in_flight: state[:in_flight] - 1, dead_letter: state[:dead_letter] + 1)
    end

    def run!(sut, args)
      JobQueueRetryDeadLetterPbtSupport.before_run_hook&.call(sut)
      payload = JobQueueRetryDeadLetterPbtSupport.adapt_args(name, args)
      method_name = JobQueueRetryDeadLetterPbtSupport.resolve_method_name(name, :dead_letter)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(JobQueueRetryDeadLetterPbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = JobQueueRetryDeadLetterPbtSupport.adapt_result(name, result)
      JobQueueRetryDeadLetterPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#j.in_flight>0 implies#j'.in_flight=sub[#j.in_flight,1]and#j'.dead_letter=add[#j.dead_letter,1]"
      # Analyzer hints: state_field="in_flight", size_delta=1, transition_kind=nil, requires_non_empty_state=true, scalar_update_kind=:decrement_like, command_confidence=:medium, guard_kind=:non_empty, guard_field="in_flight", guard_constant=nil, rhs_source_kind=:unknown, state_update_shape=:decrement
      # Related Alloy property predicates: Enqueue, Dispatch, Ack, Retry
      # Related pattern hints: size
      # Derived verify hints: respect_non_empty_guard, check_size_semantics, check_guard_failure_semantics
      policy = JobQueueRetryDeadLetterPbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if JobQueueRetryDeadLetterPbtSupport.call_verify_override(
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
        observed = JobQueueRetryDeadLetterPbtSupport.observed_state(sut)
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
      observed = JobQueueRetryDeadLetterPbtSupport.observed_state(sut)
      if !observed.nil?
        expected_observed_state = after_state
        raise "Expected observed state to match model" unless observed == expected_observed_state
      end
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Jobs#in_flight
      # Derived from related assertions/facts: respect the non-empty guard before removal-style checks
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      before_in_flight = before_state[:in_flight]
      after_in_flight = after_state[:in_flight]
      raise "Expected decremented value for Jobs#in_flight" unless after_in_flight == before_in_flight - 1
      before_dead_letter = before_state[:dead_letter]
      after_dead_letter = after_state[:dead_letter]
      raise "Expected incremented value for Jobs#dead_letter" unless after_dead_letter == before_dead_letter + 1
      raise "Expected total scalar value to stay the same" unless after_in_flight + after_dead_letter == before_in_flight + before_dead_letter
      [sut, args] && nil
    end
  end

end