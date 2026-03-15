# frozen_string_literal: true

require "pbt"
require "rspec"
require_relative "job_status_event_counters_impl"
require_relative "job_status_event_counters_pbt_config" if File.exist?(File.expand_path("job_status_event_counters_pbt_config.rb", __dir__))

if File.exist?(File.expand_path("job_status_event_counters_pbt_config.rb", __dir__)) && !defined?(::JobStatusEventCountersPbtConfig)
  raise "Expected JobStatusEventCountersPbtConfig to be defined in job_status_event_counters_pbt_config.rb"
end

unless Pbt.respond_to?(:stateful)
  loaded_pbt_version = defined?(Gem.loaded_specs) ? Gem.loaded_specs["pbt"]&.version&.to_s : nil
  detail = loaded_pbt_version ? "loaded pbt #{loaded_pbt_version}" : "loaded pbt version unknown"
  raise "Expected pbt >= 0.5.1 with Pbt.stateful (#{detail}). Install a compatible pbt release before running this scaffold."
end

RSpec.describe "job_status_event_counters (stateful scaffold)" do
  # Regeneration-safe customization:
  # - edit job_status_event_counters_pbt_config.rb for SUT wiring and durable API mapping
  # - edit job_status_event_counters_impl.rb for implementation behavior
  # - edit this scaffold only for one-off refinements when needed

  module JobStatusEventCountersPbtSupport
    module_function
    ARGUMENTS_OVERRIDE_UNSET = Object.new.freeze

    def config
      defined?(::JobStatusEventCountersPbtConfig) ? ::JobStatusEventCountersPbtConfig : {}
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
        model: JobStatusEventCountersModel.new,
        sut: -> { JobStatusEventCountersPbtSupport.sut_factory(-> { JobStatusEventCountersImpl.new }).call },
        max_steps: 20
      )
    end
  end

  class JobStatusEventCountersModel
    def initialize
      @commands = [
        ActivateCommand.new,
        RetryCommand.new,
        DeactivateCommand.new
      ]
    end

    def initial_state
      default_state = { events: [], status: 0, retry_budget: 0, retry_count: 0 } # TODO: replace with a domain-specific structured model state
      JobStatusEventCountersPbtSupport.initial_state(default_state)
    end

    def commands(_state)
      @commands
    end
  end

  class ActivateCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :activate
    end

    def arguments
      overridden = JobStatusEventCountersPbtSupport.call_arguments_override(name)
      return overridden unless overridden.equal?(JobStatusEventCountersPbtSupport::ARGUMENTS_OVERRIDE_UNSET)
      Pbt.nil
    end

    def applicable?(state)
      override = JobStatusEventCountersPbtSupport.applicable_override(name)
      return JobStatusEventCountersPbtSupport.call_applicable_override(override, state, nil) if override
      return true if JobStatusEventCountersPbtSupport.guard_failure_policy(name)
      guard_satisfied?(state)
    end

    def guard_satisfied?(state, _args = nil)
      state[:status] == 0 # inferred structured collection/status precondition for activate
    end

    def next_state(state, args)
      override = JobStatusEventCountersPbtSupport.next_state_override(name)
      return JobStatusEventCountersPbtSupport.call_next_state_override(override, state, args) if override
      return state if JobStatusEventCountersPbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      # Inferred transition target: Job#events
      state.merge(events: state[:events], status: 1, retry_budget: state[:retry_budget], retry_count: state[:retry_count])
    end

    def run!(sut, args)
      JobStatusEventCountersPbtSupport.before_run_hook&.call(sut)
      payload = JobStatusEventCountersPbtSupport.adapt_args(name, args)
      method_name = JobStatusEventCountersPbtSupport.resolve_method_name(name, :activate)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(JobStatusEventCountersPbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = JobStatusEventCountersPbtSupport.adapt_result(name, result)
      JobStatusEventCountersPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#j.status=0 implies#j'.status=1 and#j'.events=#j.events and#j'.retry_budget=#j.retry_budget and#j'.retry_count=#j.retry_count"
      # Analyzer hints: state_field="events", size_delta=0, transition_kind=:size_no_change, requires_non_empty_state=false, scalar_update_kind=nil, command_confidence=:medium, guard_kind=:state_equals_constant, guard_field="status", guard_constant="0", rhs_source_kind=:constant, state_update_shape=:preserve_size
      # Derived verify hints: check_guard_failure_semantics
      policy = JobStatusEventCountersPbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if JobStatusEventCountersPbtSupport.call_verify_override(
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
        observed = JobStatusEventCountersPbtSupport.observed_state(sut)
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
      observed = JobStatusEventCountersPbtSupport.observed_state(sut)
      if !observed.nil?
        expected_observed_state = after_state
        raise "Expected observed state to match model" unless observed == expected_observed_state
      end
      # Inferred collection target: Job#events
      before_items = before_state[:events]
      after_items = after_state[:events]
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      raise "Expected size to stay the same" unless after_items.length == before_items.length
      before_status = before_state[:status]
      after_status = after_state[:status]
      expected_status = 1
      raise "Expected replaced value for Job#status" unless after_status == expected_status
      before_retry_budget = before_state[:retry_budget]
      after_retry_budget = after_state[:retry_budget]
      raise "Expected preserved value for Job#retry_budget" unless after_retry_budget == before_retry_budget
      before_retry_count = before_state[:retry_count]
      after_retry_count = after_state[:retry_count]
      raise "Expected preserved value for Job#retry_count" unless after_retry_count == before_retry_count
      # TODO: add concrete collection checks for Activate
      [sut, args] && nil
    end
  end

  class RetryCommand
    def name
      :retry
    end

    def arguments
      overridden = JobStatusEventCountersPbtSupport.call_arguments_override(name)
      return overridden unless overridden.equal?(JobStatusEventCountersPbtSupport::ARGUMENTS_OVERRIDE_UNSET)
      Pbt.nil
    end

    def applicable?(state)
      override = JobStatusEventCountersPbtSupport.applicable_override(name)
      return JobStatusEventCountersPbtSupport.call_applicable_override(override, state, nil) if override
      return true if JobStatusEventCountersPbtSupport.guard_failure_policy(name)
      guard_satisfied?(state)
    end

    def guard_satisfied?(state, _args = nil)
      state[:retry_budget] > 0 # inferred structured collection/scalar guard for retry
    end

    def next_state(state, args)
      override = JobStatusEventCountersPbtSupport.next_state_override(name)
      return JobStatusEventCountersPbtSupport.call_next_state_override(override, state, args) if override
      return state if JobStatusEventCountersPbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      # Inferred transition target: Job#events
      delta = JobStatusEventCountersPbtSupport.scalar_model_arg(name, args)
      state.merge(events: state[:events] + [1], status: state[:status], retry_budget: state[:retry_budget] - 1, retry_count: state[:retry_count] + 1)
    end

    def run!(sut, args)
      JobStatusEventCountersPbtSupport.before_run_hook&.call(sut)
      payload = JobStatusEventCountersPbtSupport.adapt_args(name, args)
      method_name = JobStatusEventCountersPbtSupport.resolve_method_name(name, :retry)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(JobStatusEventCountersPbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = JobStatusEventCountersPbtSupport.adapt_result(name, result)
      JobStatusEventCountersPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#j.status=1 and#j.retry_budget>0 implies#j'.status=#j.status and#j'.events=add[#j.events,1]and#j'.retry_budget=sub[#j.retry_budget,1]and#j'.retry_count=add[#j.retry_count,1]"
      # Analyzer hints: state_field="events", size_delta=1, transition_kind=:append, requires_non_empty_state=true, scalar_update_kind=nil, command_confidence=:high, guard_kind=:non_empty, guard_field="retry_budget", guard_constant=nil, rhs_source_kind=:unknown, state_update_shape=:append_like
      # Derived verify hints: respect_non_empty_guard, check_guard_failure_semantics
      policy = JobStatusEventCountersPbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if JobStatusEventCountersPbtSupport.call_verify_override(
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
        observed = JobStatusEventCountersPbtSupport.observed_state(sut)
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
      observed = JobStatusEventCountersPbtSupport.observed_state(sut)
      if !observed.nil?
        expected_observed_state = after_state
        raise "Expected observed state to match model" unless observed == expected_observed_state
      end
      # Inferred collection target: Job#events
      before_items = before_state[:events]
      after_items = after_state[:events]
      # Derived from related assertions/facts: respect the non-empty guard before removal-style checks
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      expected_size = before_items.length + 1
      raise "Expected size to increase by 1" unless after_items.length == expected_size
      before_status = before_state[:status]
      after_status = after_state[:status]
      raise "Expected preserved value for Job#status" unless after_status == before_status
      before_retry_budget = before_state[:retry_budget]
      after_retry_budget = after_state[:retry_budget]
      raise "Expected decremented value for Job#retry_budget" unless after_retry_budget == before_retry_budget - 1
      before_retry_count = before_state[:retry_count]
      after_retry_count = after_state[:retry_count]
      raise "Expected incremented value for Job#retry_count" unless after_retry_count == before_retry_count + 1
      [sut, args] && nil
    end
  end

  class DeactivateCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :deactivate
    end

    def arguments
      overridden = JobStatusEventCountersPbtSupport.call_arguments_override(name)
      return overridden unless overridden.equal?(JobStatusEventCountersPbtSupport::ARGUMENTS_OVERRIDE_UNSET)
      Pbt.nil
    end

    def applicable?(state)
      override = JobStatusEventCountersPbtSupport.applicable_override(name)
      return JobStatusEventCountersPbtSupport.call_applicable_override(override, state, nil) if override
      return true if JobStatusEventCountersPbtSupport.guard_failure_policy(name)
      guard_satisfied?(state)
    end

    def guard_satisfied?(state, _args = nil)
      state[:status] == 1 # inferred structured collection/status precondition for deactivate
    end

    def next_state(state, args)
      override = JobStatusEventCountersPbtSupport.next_state_override(name)
      return JobStatusEventCountersPbtSupport.call_next_state_override(override, state, args) if override
      return state if JobStatusEventCountersPbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      # Inferred transition target: Job#events
      state.merge(events: state[:events], status: 2, retry_budget: state[:retry_budget], retry_count: state[:retry_count])
    end

    def run!(sut, args)
      JobStatusEventCountersPbtSupport.before_run_hook&.call(sut)
      payload = JobStatusEventCountersPbtSupport.adapt_args(name, args)
      method_name = JobStatusEventCountersPbtSupport.resolve_method_name(name, :deactivate)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(JobStatusEventCountersPbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = JobStatusEventCountersPbtSupport.adapt_result(name, result)
      JobStatusEventCountersPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#j.status=1 implies#j'.status=2 and#j'.events=#j.events and#j'.retry_budget=#j.retry_budget and#j'.retry_count=#j.retry_count"
      # Analyzer hints: state_field="events", size_delta=0, transition_kind=:size_no_change, requires_non_empty_state=false, scalar_update_kind=nil, command_confidence=:medium, guard_kind=:state_equals_constant, guard_field="status", guard_constant="1", rhs_source_kind=:constant, state_update_shape=:preserve_size
      # Derived verify hints: check_guard_failure_semantics
      policy = JobStatusEventCountersPbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if JobStatusEventCountersPbtSupport.call_verify_override(
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
        observed = JobStatusEventCountersPbtSupport.observed_state(sut)
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
      observed = JobStatusEventCountersPbtSupport.observed_state(sut)
      if !observed.nil?
        expected_observed_state = after_state
        raise "Expected observed state to match model" unless observed == expected_observed_state
      end
      # Inferred collection target: Job#events
      before_items = before_state[:events]
      after_items = after_state[:events]
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      raise "Expected size to stay the same" unless after_items.length == before_items.length
      before_status = before_state[:status]
      after_status = after_state[:status]
      expected_status = 2
      raise "Expected replaced value for Job#status" unless after_status == expected_status
      before_retry_budget = before_state[:retry_budget]
      after_retry_budget = after_state[:retry_budget]
      raise "Expected preserved value for Job#retry_budget" unless after_retry_budget == before_retry_budget
      before_retry_count = before_state[:retry_count]
      after_retry_count = after_state[:retry_count]
      raise "Expected preserved value for Job#retry_count" unless after_retry_count == before_retry_count
      # TODO: add concrete collection checks for Deactivate
      [sut, args] && nil
    end
  end

end