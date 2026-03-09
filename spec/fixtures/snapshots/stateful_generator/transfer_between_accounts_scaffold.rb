# frozen_string_literal: true

require "pbt"
require "rspec"
require_relative "transfer_between_accounts_impl"
require_relative "transfer_between_accounts_pbt_config" if File.exist?(File.expand_path("transfer_between_accounts_pbt_config.rb", __dir__))

if File.exist?(File.expand_path("transfer_between_accounts_pbt_config.rb", __dir__)) && !defined?(::TransferBetweenAccountsPbtConfig)
  raise "Expected TransferBetweenAccountsPbtConfig to be defined in transfer_between_accounts_pbt_config.rb"
end

RSpec.describe "transfer_between_accounts (stateful scaffold)" do
  # Regeneration-safe customization:
  # - edit transfer_between_accounts_pbt_config.rb for SUT wiring and durable API mapping
  # - edit transfer_between_accounts_impl.rb for implementation behavior
  # - edit this scaffold only for one-off refinements when needed

  module TransferBetweenAccountsPbtSupport
    module_function

    def config
      defined?(::TransferBetweenAccountsPbtConfig) ? ::TransferBetweenAccountsPbtConfig : {}
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
        model: TransferBetweenAccountsModel.new,
        sut: -> { TransferBetweenAccountsPbtSupport.sut_factory(-> { TransferBetweenAccountsImpl.new }).call },
        max_steps: 20
      )
    end
  end

  class TransferBetweenAccountsModel
    def initialize
      @commands = [
        TransferCommand.new
      ]
    end

    def initial_state
      default_state = { source_balance: 0, target_balance: 0 } # TODO: replace with a domain-specific structured model state
      TransferBetweenAccountsPbtSupport.initial_state(default_state)
    end

    def commands(_state)
      @commands
    end
  end

  class TransferCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :transfer
    end

    def arguments(state)
      Pbt.integer(min: 1, max: state[:source_balance])
    end

    def applicable?(state, args)
      override = TransferBetweenAccountsPbtSupport.applicable_override(name)
      return TransferBetweenAccountsPbtSupport.call_applicable_override(override, state, args) if override
      delta = TransferBetweenAccountsPbtSupport.scalar_model_arg(name, args)
      current_value = state[:source_balance]
      delta.is_a?(Numeric) && delta.positive? && delta <= current_value
    end

    def next_state(state, args)
      override = TransferBetweenAccountsPbtSupport.next_state_override(name)
      return TransferBetweenAccountsPbtSupport.call_next_state_override(override, state, args) if override
      delta = TransferBetweenAccountsPbtSupport.scalar_model_arg(name, args)
      state.merge(source_balance: state[:source_balance] - delta, target_balance: state[:target_balance] + delta)
    end

    def run!(sut, args)
      TransferBetweenAccountsPbtSupport.before_run_hook&.call(sut)
      payload = TransferBetweenAccountsPbtSupport.adapt_args(name, args)
      method_name = TransferBetweenAccountsPbtSupport.resolve_method_name(name, :transfer)
      result = if payload.nil?
        sut.public_send(method_name)
      elsif payload.is_a?(Array)
        sut.public_send(method_name, *payload)
      else
        sut.public_send(method_name, payload)
      end
      adapted_result = TransferBetweenAccountsPbtSupport.adapt_result(name, result)
      TransferBetweenAccountsPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#a.source_balance>=amount implies#a'.source_balance=sub[#a.source_balance,amount]and#a'.target_balance=add[#a.target_balance,amount]"
      # Analyzer hints: state_field="source_balance", size_delta=1, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:decrement_like, command_confidence=:medium, guard_kind=:arg_within_state, rhs_source_kind=:arg, state_update_shape=:decrement
      # Related Alloy property predicates: NonNegativeSource
      # Derived verify hints: check_non_negative_scalar_state, check_guard_failure_semantics
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if TransferBetweenAccountsPbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut
      )
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Accounts#source_balance
      # Derived from related assertions/facts: keep non-negative scalar invariants aligned with the model state
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      delta = TransferBetweenAccountsPbtSupport.scalar_model_arg(name, args)
      before_source_balance = before_state[:source_balance]
      after_source_balance = after_state[:source_balance]
      raise "Expected sufficient scalar state before decrement" unless delta <= before_source_balance
      raise "Expected decremented value for Accounts#source_balance" unless after_source_balance == before_source_balance - delta
      raise "Expected non-negative value for Accounts#source_balance" unless after_source_balance >= 0
      before_target_balance = before_state[:target_balance]
      after_target_balance = after_state[:target_balance]
      raise "Expected incremented value for Accounts#target_balance" unless after_target_balance == before_target_balance + delta
      raise "Expected non-negative value for Accounts#target_balance" unless after_target_balance >= 0
      raise "Expected total scalar value to stay the same" unless after_source_balance + after_target_balance == before_source_balance + before_target_balance
      [sut, args] && nil
    end
  end

end