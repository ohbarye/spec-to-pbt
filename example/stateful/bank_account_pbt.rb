# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path(ENV.fetch("PBT_REPO_DIR", "../../../pbt") + "/lib", __dir__)) if Dir.exist?(File.expand_path(ENV.fetch("PBT_REPO_DIR", "../../../pbt"), __dir__))

require "pbt"
require "rspec"
require_relative "bank_account_impl"
require_relative "bank_account_pbt_config"

RSpec.describe "bank_account (stateful scaffold)" do
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

    def model_arg(command_name, args)
      adapter = command_config(command_name)[:model_arg_adapter]
      payload = adapter ? adapter.call(args) : args
      payload.is_a?(Array) && payload.length == 1 ? payload.first : payload
    end

    def call_verify_override(command_name, **kwargs)
      override = verify_override(command_name)
      return false unless override

      override.call(**kwargs.merge(observed_state: observed_state(kwargs[:sut])))
      true
    end
  end

  it "wires a bank-account scaffold with config-driven API remapping" do
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
        DepositAmountCommand.new,
        WithdrawAmountCommand.new
      ]
    end

    def initial_state
      0
    end

    def commands(_state)
      @commands
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
      amount = BankAccountPbtSupport.model_arg(name, args)
      state + amount
    end

    def run!(sut, args)
      amount = BankAccountPbtSupport.model_arg(name, args)
      sut.public_send(BankAccountPbtSupport.resolve_method_name(name, :deposit_amount), amount)
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      return nil if BankAccountPbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut
      )

      amount = BankAccountPbtSupport.model_arg(name, args)
      raise "Expected deposit to increase balance by amount" unless after_state == before_state + amount
      nil
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

      amount = BankAccountPbtSupport.model_arg(name, args)
      amount.positive? && amount <= state
    end

    def next_state(state, args)
      amount = BankAccountPbtSupport.model_arg(name, args)
      state - amount
    end

    def run!(sut, args)
      amount = BankAccountPbtSupport.model_arg(name, args)
      sut.public_send(BankAccountPbtSupport.resolve_method_name(name, :withdraw_amount), amount)
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      return nil if BankAccountPbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut
      )

      amount = BankAccountPbtSupport.model_arg(name, args)
      raise "Expected sufficient balance before withdrawal" unless amount <= before_state
      raise "Expected withdraw to decrease balance by amount" unless after_state == before_state - amount
      nil
    end
  end
end
