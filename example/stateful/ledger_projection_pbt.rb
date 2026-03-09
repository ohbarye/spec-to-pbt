# frozen_string_literal: true

require_relative "pbt_local"
require "rspec"
require_relative "ledger_projection_impl"
require_relative "ledger_projection_pbt_config" if File.exist?(File.expand_path("ledger_projection_pbt_config.rb", __dir__))

if File.exist?(File.expand_path("ledger_projection_pbt_config.rb", __dir__)) && !defined?(::LedgerProjectionPbtConfig)
  raise "Expected LedgerProjectionPbtConfig to be defined in ledger_projection_pbt_config.rb"
end

RSpec.describe "ledger_projection (stateful scaffold)" do
  # Regeneration-safe customization:
  # - edit ledger_projection_pbt_config.rb for SUT wiring and durable API mapping
  # - edit ledger_projection_impl.rb for implementation behavior
  # - edit this scaffold only for one-off refinements when needed

  module LedgerProjectionPbtSupport
    module_function

    def config
      defined?(::LedgerProjectionPbtConfig) ? ::LedgerProjectionPbtConfig : {}
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
        model: LedgerProjectionModel.new,
        sut: -> { LedgerProjectionPbtSupport.sut_factory(-> { LedgerProjectionImpl.new }).call },
        max_steps: 20
      )
    end
  end

  class LedgerProjectionModel
    def initialize
      @commands = [
        PostCreditCommand.new,
        PostDebitCommand.new
      ]
    end

    def initial_state
      default_state = { entries: [], balance: 0 } # TODO: replace with a domain-specific structured model state
      LedgerProjectionPbtSupport.initial_state(default_state)
    end

    def commands(_state)
      @commands
    end
  end

  class PostCreditCommand
    def name
      :post_credit
    end

    def arguments
      Pbt.integer
    end

    def applicable?(state)
      override = LedgerProjectionPbtSupport.applicable_override(name)
      return LedgerProjectionPbtSupport.call_applicable_override(override, state, nil) if override
      true
    end

    def next_state(state, args)
      override = LedgerProjectionPbtSupport.next_state_override(name)
      return LedgerProjectionPbtSupport.call_next_state_override(override, state, args) if override
      # Inferred transition target: Ledger#entries
      delta = LedgerProjectionPbtSupport.scalar_model_arg(name, args)
      state.merge(entries: state[:entries] + [delta], balance: state[:balance] + delta)
    end

    def run!(sut, args)
      LedgerProjectionPbtSupport.before_run_hook&.call(sut)
      payload = LedgerProjectionPbtSupport.adapt_args(name, args)
      method_name = LedgerProjectionPbtSupport.resolve_method_name(name, :post_credit)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless LedgerProjectionPbtSupport.guard_failure_policy(name) == :raise
        error
      end
      adapted_result = LedgerProjectionPbtSupport.adapt_result(name, result)
      LedgerProjectionPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#l'.entries=add[#l.entries,1]and#l'.balance=add[#l.balance,amount]"
      # Analyzer hints: state_field="entries", size_delta=1, transition_kind=:append, requires_non_empty_state=false, scalar_update_kind=nil, command_confidence=:high, guard_kind=:none, rhs_source_kind=:arg, state_update_shape=:append_like
      # Derived verify hints: check_projection_semantics
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if LedgerProjectionPbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut
      )
      # Inferred collection target: Ledger#entries
      before_items = before_state[:entries]
      after_items = after_state[:entries]
      # Derived from collection/scalar updates: verify append-only projection semantics against companion scalar fields
      expected_size = before_items.length + 1
      raise "Expected size to increase by 1" unless after_items.length == expected_size
      delta = LedgerProjectionPbtSupport.scalar_model_arg(name, args)
      raise "Expected appended projection entry to match the model delta" unless after_items.last == delta
      before_balance = before_state[:balance]
      after_balance = after_state[:balance]
      raise "Expected incremented value for Ledger#balance" unless after_balance == before_balance + delta
      [sut, args] && nil
    end
  end

  class PostDebitCommand
    def name
      :post_debit
    end

    def arguments
      Pbt.integer
    end

    def applicable?(state)
      override = LedgerProjectionPbtSupport.applicable_override(name)
      return LedgerProjectionPbtSupport.call_applicable_override(override, state, nil) if override
      true
    end

    def next_state(state, args)
      override = LedgerProjectionPbtSupport.next_state_override(name)
      return LedgerProjectionPbtSupport.call_next_state_override(override, state, args) if override
      # Inferred transition target: Ledger#entries
      delta = LedgerProjectionPbtSupport.scalar_model_arg(name, args)
      state.merge(entries: state[:entries] + [-delta], balance: state[:balance] - delta)
    end

    def run!(sut, args)
      LedgerProjectionPbtSupport.before_run_hook&.call(sut)
      payload = LedgerProjectionPbtSupport.adapt_args(name, args)
      method_name = LedgerProjectionPbtSupport.resolve_method_name(name, :post_debit)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless LedgerProjectionPbtSupport.guard_failure_policy(name) == :raise
        error
      end
      adapted_result = LedgerProjectionPbtSupport.adapt_result(name, result)
      LedgerProjectionPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#l'.entries=add[#l.entries,1]and#l'.balance=sub[#l.balance,amount]"
      # Analyzer hints: state_field="entries", size_delta=1, transition_kind=:append, requires_non_empty_state=false, scalar_update_kind=nil, command_confidence=:high, guard_kind=:none, rhs_source_kind=:arg, state_update_shape=:append_like
      # Derived verify hints: check_projection_semantics
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if LedgerProjectionPbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut
      )
      # Inferred collection target: Ledger#entries
      before_items = before_state[:entries]
      after_items = after_state[:entries]
      # Derived from collection/scalar updates: verify append-only projection semantics against companion scalar fields
      expected_size = before_items.length + 1
      raise "Expected size to increase by 1" unless after_items.length == expected_size
      delta = LedgerProjectionPbtSupport.scalar_model_arg(name, args)
      raise "Expected appended projection entry to match the model delta" unless after_items.last == -delta
      before_balance = before_state[:balance]
      after_balance = after_state[:balance]
      raise "Expected decremented value for Ledger#balance" unless after_balance == before_balance - delta
      [sut, args] && nil
    end
  end

end