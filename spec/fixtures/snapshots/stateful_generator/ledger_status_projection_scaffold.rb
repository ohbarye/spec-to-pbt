# frozen_string_literal: true

require "pbt"
require "rspec"
require_relative "ledger_status_projection_impl"
require_relative "ledger_status_projection_pbt_config" if File.exist?(File.expand_path("ledger_status_projection_pbt_config.rb", __dir__))

if File.exist?(File.expand_path("ledger_status_projection_pbt_config.rb", __dir__)) && !defined?(::LedgerStatusProjectionPbtConfig)
  raise "Expected LedgerStatusProjectionPbtConfig to be defined in ledger_status_projection_pbt_config.rb"
end

RSpec.describe "ledger_status_projection (stateful scaffold)" do
  # Regeneration-safe customization:
  # - edit ledger_status_projection_pbt_config.rb for SUT wiring and durable API mapping
  # - edit ledger_status_projection_impl.rb for implementation behavior
  # - edit this scaffold only for one-off refinements when needed

  module LedgerStatusProjectionPbtSupport
    module_function

    def config
      defined?(::LedgerStatusProjectionPbtConfig) ? ::LedgerStatusProjectionPbtConfig : {}
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
        model: LedgerStatusProjectionModel.new,
        sut: -> { LedgerStatusProjectionPbtSupport.sut_factory(-> { LedgerStatusProjectionImpl.new }).call },
        max_steps: 20
      )
    end
  end

  class LedgerStatusProjectionModel
    def initialize
      @commands = [
        OpenCommand.new,
        PostAmountCommand.new,
        CloseCommand.new
      ]
    end

    def initial_state
      default_state = { entries: [], status: 0, balance: 0 } # TODO: replace with a domain-specific structured model state
      LedgerStatusProjectionPbtSupport.initial_state(default_state)
    end

    def commands(_state)
      @commands
    end
  end

  class OpenCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :open
    end

    def arguments
      Pbt.nil
    end

    def applicable?(state)
      override = LedgerStatusProjectionPbtSupport.applicable_override(name)
      return LedgerStatusProjectionPbtSupport.call_applicable_override(override, state, nil) if override
      return true if LedgerStatusProjectionPbtSupport.guard_failure_policy(name)
      guard_satisfied?(state)
    end

    def guard_satisfied?(state, _args = nil)
      state[:status] == 0 # inferred structured collection/status precondition for open
    end

    def next_state(state, args)
      override = LedgerStatusProjectionPbtSupport.next_state_override(name)
      return LedgerStatusProjectionPbtSupport.call_next_state_override(override, state, args) if override
      return state if LedgerStatusProjectionPbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      # Inferred transition target: Ledger#entries
      state.merge(entries: state[:entries], status: 1, balance: state[:balance])
    end

    def run!(sut, args)
      LedgerStatusProjectionPbtSupport.before_run_hook&.call(sut)
      payload = LedgerStatusProjectionPbtSupport.adapt_args(name, args)
      method_name = LedgerStatusProjectionPbtSupport.resolve_method_name(name, :open)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(LedgerStatusProjectionPbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = LedgerStatusProjectionPbtSupport.adapt_result(name, result)
      LedgerStatusProjectionPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#l.status=0 implies#l'.status=1 and#l'.entries=#l.entries and#l'.balance=#l.balance"
      # Analyzer hints: state_field="entries", size_delta=0, transition_kind=:size_no_change, requires_non_empty_state=false, scalar_update_kind=nil, command_confidence=:medium, guard_kind=:state_equals_constant, guard_field="status", guard_constant="0", rhs_source_kind=:constant, state_update_shape=:preserve_size
      # Derived verify hints: check_guard_failure_semantics
      policy = LedgerStatusProjectionPbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if LedgerStatusProjectionPbtSupport.call_verify_override(
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
        observed = LedgerStatusProjectionPbtSupport.observed_state(sut)
        case policy
        when :no_op
          raise "Expected unchanged model state on guard failure" unless after_state == before_state
          raise "Expected unchanged observed state on guard failure" if !observed.nil? && observed != after_state[:entries]
        when :raise
          raise "Expected guard failure to surface as an exception" unless result.is_a?(StandardError)
          raise "Expected unchanged model state on guard failure" unless after_state == before_state
          raise "Expected unchanged observed state on guard failure" if !observed.nil? && observed != after_state[:entries]
        when :custom
          raise "guard_failure_policy :custom requires verify_override to assert invalid-path semantics"
        else
          raise "Unsupported guard_failure_policy: #{policy.inspect}"
        end
        return nil
      end
      # Inferred collection target: Ledger#entries
      before_items = before_state[:entries]
      after_items = after_state[:entries]
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      raise "Expected size to stay the same" unless after_items.length == before_items.length
      before_status = before_state[:status]
      after_status = after_state[:status]
      expected_status = 1
      raise "Expected replaced value for Ledger#status" unless after_status == expected_status
      before_balance = before_state[:balance]
      after_balance = after_state[:balance]
      raise "Expected preserved value for Ledger#balance" unless after_balance == before_balance
      # TODO: add concrete collection checks for Open
      [sut, args] && nil
    end
  end

  class PostAmountCommand
    def name
      :post_amount
    end

    def arguments
      Pbt.integer
    end

    def applicable?(state)
      override = LedgerStatusProjectionPbtSupport.applicable_override(name)
      return LedgerStatusProjectionPbtSupport.call_applicable_override(override, state, nil) if override
      return true if LedgerStatusProjectionPbtSupport.guard_failure_policy(name)
      guard_satisfied?(state)
    end

    def guard_satisfied?(state, _args = nil)
      state[:status] == 1 # inferred structured collection/status precondition for post_amount
    end

    def next_state(state, args)
      override = LedgerStatusProjectionPbtSupport.next_state_override(name)
      return LedgerStatusProjectionPbtSupport.call_next_state_override(override, state, args) if override
      return state if LedgerStatusProjectionPbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      # Inferred transition target: Ledger#entries
      delta = LedgerStatusProjectionPbtSupport.scalar_model_arg(name, args)
      state.merge(entries: state[:entries] + [delta], status: state[:status], balance: state[:balance] + delta)
    end

    def run!(sut, args)
      LedgerStatusProjectionPbtSupport.before_run_hook&.call(sut)
      payload = LedgerStatusProjectionPbtSupport.adapt_args(name, args)
      method_name = LedgerStatusProjectionPbtSupport.resolve_method_name(name, :post_amount)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(LedgerStatusProjectionPbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = LedgerStatusProjectionPbtSupport.adapt_result(name, result)
      LedgerStatusProjectionPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#l.status=1 implies#l'.status=#l.status and#l'.entries=add[#l.entries,1]and#l'.balance=add[#l.balance,amount]"
      # Analyzer hints: state_field="entries", size_delta=1, transition_kind=:append, requires_non_empty_state=false, scalar_update_kind=nil, command_confidence=:high, guard_kind=:state_equals_constant, guard_field="status", guard_constant="1", rhs_source_kind=:state_field, state_update_shape=:append_like
      # Derived verify hints: check_projection_semantics, check_guard_failure_semantics
      policy = LedgerStatusProjectionPbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if LedgerStatusProjectionPbtSupport.call_verify_override(
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
        observed = LedgerStatusProjectionPbtSupport.observed_state(sut)
        case policy
        when :no_op
          raise "Expected unchanged model state on guard failure" unless after_state == before_state
          raise "Expected unchanged observed state on guard failure" if !observed.nil? && observed != after_state[:entries]
        when :raise
          raise "Expected guard failure to surface as an exception" unless result.is_a?(StandardError)
          raise "Expected unchanged model state on guard failure" unless after_state == before_state
          raise "Expected unchanged observed state on guard failure" if !observed.nil? && observed != after_state[:entries]
        when :custom
          raise "guard_failure_policy :custom requires verify_override to assert invalid-path semantics"
        else
          raise "Unsupported guard_failure_policy: #{policy.inspect}"
        end
        return nil
      end
      # Inferred collection target: Ledger#entries
      before_items = before_state[:entries]
      after_items = after_state[:entries]
      # Derived from collection/scalar updates: verify append-only projection semantics against companion scalar fields
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      expected_size = before_items.length + 1
      raise "Expected size to increase by 1" unless after_items.length == expected_size
      delta = LedgerStatusProjectionPbtSupport.scalar_model_arg(name, args)
      raise "Expected appended projection entry to match the model delta" unless after_items.last == delta
      before_status = before_state[:status]
      after_status = after_state[:status]
      raise "Expected preserved value for Ledger#status" unless after_status == before_status
      before_balance = before_state[:balance]
      after_balance = after_state[:balance]
      raise "Expected incremented value for Ledger#balance" unless after_balance == before_balance + delta
      [sut, args] && nil
    end
  end

  class CloseCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :close
    end

    def arguments
      Pbt.nil
    end

    def applicable?(state)
      override = LedgerStatusProjectionPbtSupport.applicable_override(name)
      return LedgerStatusProjectionPbtSupport.call_applicable_override(override, state, nil) if override
      return true if LedgerStatusProjectionPbtSupport.guard_failure_policy(name)
      guard_satisfied?(state)
    end

    def guard_satisfied?(state, _args = nil)
      state[:status] == 1 # inferred structured collection/status precondition for close
    end

    def next_state(state, args)
      override = LedgerStatusProjectionPbtSupport.next_state_override(name)
      return LedgerStatusProjectionPbtSupport.call_next_state_override(override, state, args) if override
      return state if LedgerStatusProjectionPbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      # Inferred transition target: Ledger#entries
      state.merge(entries: state[:entries], status: 2, balance: state[:balance])
    end

    def run!(sut, args)
      LedgerStatusProjectionPbtSupport.before_run_hook&.call(sut)
      payload = LedgerStatusProjectionPbtSupport.adapt_args(name, args)
      method_name = LedgerStatusProjectionPbtSupport.resolve_method_name(name, :close)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(LedgerStatusProjectionPbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = LedgerStatusProjectionPbtSupport.adapt_result(name, result)
      LedgerStatusProjectionPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#l.status=1 implies#l'.status=2 and#l'.entries=#l.entries and#l'.balance=#l.balance"
      # Analyzer hints: state_field="entries", size_delta=0, transition_kind=:size_no_change, requires_non_empty_state=false, scalar_update_kind=nil, command_confidence=:medium, guard_kind=:state_equals_constant, guard_field="status", guard_constant="1", rhs_source_kind=:constant, state_update_shape=:preserve_size
      # Derived verify hints: check_guard_failure_semantics
      policy = LedgerStatusProjectionPbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if LedgerStatusProjectionPbtSupport.call_verify_override(
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
        observed = LedgerStatusProjectionPbtSupport.observed_state(sut)
        case policy
        when :no_op
          raise "Expected unchanged model state on guard failure" unless after_state == before_state
          raise "Expected unchanged observed state on guard failure" if !observed.nil? && observed != after_state[:entries]
        when :raise
          raise "Expected guard failure to surface as an exception" unless result.is_a?(StandardError)
          raise "Expected unchanged model state on guard failure" unless after_state == before_state
          raise "Expected unchanged observed state on guard failure" if !observed.nil? && observed != after_state[:entries]
        when :custom
          raise "guard_failure_policy :custom requires verify_override to assert invalid-path semantics"
        else
          raise "Unsupported guard_failure_policy: #{policy.inspect}"
        end
        return nil
      end
      # Inferred collection target: Ledger#entries
      before_items = before_state[:entries]
      after_items = after_state[:entries]
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      raise "Expected size to stay the same" unless after_items.length == before_items.length
      before_status = before_state[:status]
      after_status = after_state[:status]
      expected_status = 2
      raise "Expected replaced value for Ledger#status" unless after_status == expected_status
      before_balance = before_state[:balance]
      after_balance = after_state[:balance]
      raise "Expected preserved value for Ledger#balance" unless after_balance == before_balance
      # TODO: add concrete collection checks for Close
      [sut, args] && nil
    end
  end

end