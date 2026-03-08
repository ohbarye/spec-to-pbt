# frozen_string_literal: true

require "pbt"
require "rspec"
require_relative "bank_account_impl"
require_relative "bank_account_pbt_config" if File.exist?(File.expand_path("bank_account_pbt_config.rb", __dir__))

if File.exist?(File.expand_path("bank_account_pbt_config.rb", __dir__)) && !defined?(::BankAccountPbtConfig)
  raise "Expected BankAccountPbtConfig to be defined in bank_account_pbt_config.rb"
end

RSpec.describe "bank_account (stateful scaffold)" do
  # Regeneration-safe customization:
  # - edit bank_account_pbt_config.rb for SUT wiring and durable API mapping
  # - edit bank_account_impl.rb for implementation behavior
  # - edit this scaffold only for one-off refinements when needed

  module BankAccountPbtSupport
    module_function

    def config
      defined?(::BankAccountPbtConfig) ? ::BankAccountPbtConfig : {}
    end

    def sut_factory(default_factory)
      config.fetch(:sut_factory, default_factory)
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
        model: BankAccountModel.new,
        sut: -> { BankAccountPbtSupport.sut_factory(-> { BankAccountImpl.new }).call },
        max_steps: 20
      )
    end
  end

  class BankAccountModel
    def initialize
      @commands = [
        DepositCommand.new,
        DepositAmountCommand.new,
        WithdrawCommand.new,
        WithdrawAmountCommand.new
      ]
    end

    def initial_state
      0 # TODO: replace with a domain-specific scalar model state
    end

    def commands(_state)
      @commands
    end
  end

  class DepositCommand
    def name
      :deposit
    end

    def arguments
      Pbt.nil
    end

    def applicable?(state)
      override = BankAccountPbtSupport.applicable_override(name)
      return BankAccountPbtSupport.call_applicable_override(override, state, nil) if override
      true
    end

    def next_state(state, _args)
      state + 1
    end

    def run!(sut, args)
      BankAccountPbtSupport.before_run_hook&.call(sut)
      payload = BankAccountPbtSupport.adapt_args(name, args)
      method_name = BankAccountPbtSupport.resolve_method_name(name, :deposit)
      result = if payload.nil?
        sut.public_send(method_name)
      elsif payload.is_a?(Array)
        sut.public_send(method_name, *payload)
      else
        sut.public_send(method_name, payload)
      end
      adapted_result = BankAccountPbtSupport.adapt_result(name, result)
      BankAccountPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#a'.balance=#a.balance+1"
      # Analyzer hints: state_field="balance", size_delta=1, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:increment_like, command_confidence=:high, guard_kind=:none, rhs_source_kind=:state_field, state_update_shape=:increment
      # Related Alloy assertions: AccountProperties
      # Related Alloy property predicates: DepositAmount, Withdraw, WithdrawAmount, DepositWithdrawIdentity, NonNegative
      # Related pattern hints: size
      # Derived verify hints: respect_non_empty_guard, check_size_semantics, check_non_negative_scalar_state
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if BankAccountPbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut
      )
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Account#balance
      # Derived from related assertions/facts: respect the non-empty guard before removal-style checks
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from related assertions/facts: keep non-negative scalar invariants aligned with the model state
      raise "Expected incremented value for Account#balance" unless after_state == before_state + 1
      raise "Expected non-negative value for Account#balance" unless after_state >= 0
      [sut, args] && nil
    end
  end

  class DepositAmountCommand
    def name
      :deposit_amount
    end

    def arguments
      Pbt.integer
    end

    def applicable?(state)
      override = BankAccountPbtSupport.applicable_override(name)
      return BankAccountPbtSupport.call_applicable_override(override, state, nil) if override
      true
    end

    def next_state(state, args)
      delta = BankAccountPbtSupport.scalar_model_arg(name, args)
      state + delta
    end

    def run!(sut, args)
      BankAccountPbtSupport.before_run_hook&.call(sut)
      payload = BankAccountPbtSupport.adapt_args(name, args)
      method_name = BankAccountPbtSupport.resolve_method_name(name, :deposit_amount)
      result = if payload.nil?
        sut.public_send(method_name)
      elsif payload.is_a?(Array)
        sut.public_send(method_name, *payload)
      else
        sut.public_send(method_name, payload)
      end
      adapted_result = BankAccountPbtSupport.adapt_result(name, result)
      BankAccountPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#a'.balance=add[#a.balance,amount]"
      # Analyzer hints: state_field="balance", size_delta=1, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:increment_like, command_confidence=:high, guard_kind=:none, rhs_source_kind=:arg, state_update_shape=:increment
      # Related Alloy assertions: AccountProperties
      # Related Alloy property predicates: Deposit, Withdraw, WithdrawAmount, DepositWithdrawIdentity, NonNegative
      # Related pattern hints: size
      # Derived verify hints: respect_non_empty_guard, check_size_semantics, check_non_negative_scalar_state
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if BankAccountPbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut
      )
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Account#balance
      # Derived from related assertions/facts: respect the non-empty guard before removal-style checks
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from related assertions/facts: keep non-negative scalar invariants aligned with the model state
      delta = BankAccountPbtSupport.scalar_model_arg(name, args)
      raise "Expected incremented value for Account#balance" unless after_state == before_state + delta
      raise "Expected non-negative value for Account#balance" unless after_state >= 0
      [sut, args] && nil
    end
  end

  class WithdrawCommand
    def name
      :withdraw
    end

    def arguments
      Pbt.nil
    end

    def applicable?(state)
      override = BankAccountPbtSupport.applicable_override(name)
      return BankAccountPbtSupport.call_applicable_override(override, state, nil) if override
      state > 0 # inferred scalar precondition for withdraw
    end

    def next_state(state, _args)
      state - 1
    end

    def run!(sut, args)
      BankAccountPbtSupport.before_run_hook&.call(sut)
      payload = BankAccountPbtSupport.adapt_args(name, args)
      method_name = BankAccountPbtSupport.resolve_method_name(name, :withdraw)
      result = if payload.nil?
        sut.public_send(method_name)
      elsif payload.is_a?(Array)
        sut.public_send(method_name, *payload)
      else
        sut.public_send(method_name, payload)
      end
      adapted_result = BankAccountPbtSupport.adapt_result(name, result)
      BankAccountPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#a.balance>0 implies#a'.balance=#a.balance-1"
      # Analyzer hints: state_field="balance", size_delta=-1, transition_kind=nil, requires_non_empty_state=true, scalar_update_kind=:decrement_like, command_confidence=:high, guard_kind=:non_empty, rhs_source_kind=:state_field, state_update_shape=:decrement
      # Related Alloy assertions: AccountProperties
      # Related Alloy property predicates: Deposit, DepositAmount, WithdrawAmount, DepositWithdrawIdentity, NonNegative
      # Related pattern hints: size
      # Derived verify hints: respect_non_empty_guard, check_size_semantics, check_non_negative_scalar_state
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if BankAccountPbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut
      )
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Account#balance
      # Derived from related assertions/facts: respect the non-empty guard before removal-style checks
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from related assertions/facts: keep non-negative scalar invariants aligned with the model state
      raise "Expected decremented value for Account#balance" unless after_state == before_state - 1
      raise "Expected non-negative value for Account#balance" unless after_state >= 0
      [sut, args] && nil
    end
  end

  class WithdrawAmountCommand
    def name
      :withdraw_amount
    end

    def arguments(state)
      Pbt.integer(min: 1, max: state)
    end

    def applicable?(state, args)
      override = BankAccountPbtSupport.applicable_override(name)
      return BankAccountPbtSupport.call_applicable_override(override, state, args) if override
      delta = BankAccountPbtSupport.scalar_model_arg(name, args)
      delta.is_a?(Numeric) && delta.positive? && delta <= state
    end

    def next_state(state, args)
      delta = BankAccountPbtSupport.scalar_model_arg(name, args)
      state - delta
    end

    def run!(sut, args)
      BankAccountPbtSupport.before_run_hook&.call(sut)
      payload = BankAccountPbtSupport.adapt_args(name, args)
      method_name = BankAccountPbtSupport.resolve_method_name(name, :withdraw_amount)
      result = if payload.nil?
        sut.public_send(method_name)
      elsif payload.is_a?(Array)
        sut.public_send(method_name, *payload)
      else
        sut.public_send(method_name, payload)
      end
      adapted_result = BankAccountPbtSupport.adapt_result(name, result)
      BankAccountPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#a.balance>=amount implies#a'.balance=sub[#a.balance,amount]"
      # Analyzer hints: state_field="balance", size_delta=-1, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:decrement_like, command_confidence=:high, guard_kind=:arg_within_state, rhs_source_kind=:arg, state_update_shape=:decrement
      # Related Alloy assertions: AccountProperties
      # Related Alloy property predicates: Deposit, DepositAmount, Withdraw, DepositWithdrawIdentity, NonNegative
      # Related pattern hints: size
      # Derived verify hints: respect_non_empty_guard, check_size_semantics, check_non_negative_scalar_state
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if BankAccountPbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut
      )
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Account#balance
      # Derived from related assertions/facts: respect the non-empty guard before removal-style checks
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      # Derived from related assertions/facts: keep non-negative scalar invariants aligned with the model state
      raise "Expected sufficient scalar state before decrement" unless delta <= before_state
      delta = BankAccountPbtSupport.scalar_model_arg(name, args)
      raise "Expected decremented value for Account#balance" unless after_state == before_state - delta
      raise "Expected non-negative value for Account#balance" unless after_state >= 0
      [sut, args] && nil
    end
  end

end