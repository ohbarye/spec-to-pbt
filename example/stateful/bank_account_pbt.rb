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
        DepositCommand.new,
        WithdrawCommand.new
      ]
    end

    def initial_state
      0
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
      return override.call(state) if override

      true
    end

    def next_state(state, _args)
      state + 1
    end

    def run!(sut, _args)
      sut.public_send(BankAccountPbtSupport.resolve_method_name(name, :deposit))
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

      raise "Expected deposit to increase balance by 1" unless after_state == before_state + 1
      nil
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
      return override.call(state) if override

      state > 0
    end

    def next_state(state, _args)
      state - 1
    end

    def run!(sut, _args)
      sut.public_send(BankAccountPbtSupport.resolve_method_name(name, :withdraw))
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

      raise "Expected non-zero balance before withdrawal" if before_state <= 0
      raise "Expected withdraw to decrease balance by 1" unless after_state == before_state - 1
      nil
    end
  end
end
