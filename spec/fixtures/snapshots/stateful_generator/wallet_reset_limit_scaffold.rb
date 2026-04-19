# frozen_string_literal: true

require "pbt"
require_relative "wallet_reset_limit_impl" if File.exist?(File.expand_path("wallet_reset_limit_impl.rb", __dir__))
require_relative "wallet_reset_limit_pbt_config" if File.exist?(File.expand_path("wallet_reset_limit_pbt_config.rb", __dir__))

if File.exist?(File.expand_path("wallet_reset_limit_pbt_config.rb", __dir__)) && !defined?(::WalletResetLimitPbtConfig)
  raise "Expected WalletResetLimitPbtConfig to be defined in wallet_reset_limit_pbt_config.rb"
end

unless Pbt.respond_to?(:stateful)
  loaded_pbt_version = defined?(Gem.loaded_specs) ? Gem.loaded_specs["pbt"]&.version&.to_s : nil
  detail = loaded_pbt_version ? "loaded pbt #{loaded_pbt_version}" : "loaded pbt version unknown"
  raise "Expected pbt >= 0.6.0 with Pbt.stateful (#{detail}). Install a compatible pbt release before running this scaffold."
end

RSpec.describe "wallet_reset_limit (stateful scaffold)" do
  # Regeneration-safe customization:
  # - edit wallet_reset_limit_pbt_config.rb for SUT wiring and durable API mapping
  # - edit wallet_reset_limit_impl.rb for implementation behavior
  # - edit this scaffold only for one-off refinements when needed

  module WalletResetLimitPbtSupport
    module_function
    ARGUMENTS_OVERRIDE_UNSET = Object.new.freeze

    KNOWN_TOP_LEVEL_KEYS = %i[sut_factory initial_state command_mappings verify_context before_run after_run state_reader].freeze
    KNOWN_COMMAND_KEYS = %i[method arg_adapter model_arg_adapter result_adapter arguments_override applicable_override next_state_override verify_override guard_failure_policy].freeze

    def config
      defined?(::WalletResetLimitPbtConfig) ? ::WalletResetLimitPbtConfig : {}
    end

    def validate_config!
      return if config.empty?

      unknown_top = config.keys - KNOWN_TOP_LEVEL_KEYS
      raise "Unknown config keys in WalletResetLimitPbtConfig: #{unknown_top.inspect}. See docs/config-reference.md for valid keys." unless unknown_top.empty?

      config.fetch(:command_mappings, {}).each do |cmd_name, cmd_config|
        next unless cmd_config.is_a?(Hash)
        unknown_cmd = cmd_config.keys - KNOWN_COMMAND_KEYS
        raise "Unknown config keys in WalletResetLimitPbtConfig command_mappings[#{cmd_name}]: #{unknown_cmd.inspect}. See docs/config-reference.md for valid keys." unless unknown_cmd.empty?
      end

      if !config.key?(:sut_factory)
        warn "Warning: WalletResetLimitPbtConfig is missing :sut_factory (required). The scaffold will use a default factory."
      end

      if state_reader.nil?
        warn "Warning: WalletResetLimitPbtConfig has no verify_context.state_reader configured. SUT state will not be compared against the model."
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
    WalletResetLimitPbtSupport.validate_config!

    Pbt.assert(worker: :none, num_runs: 5, seed: 1) do
      Pbt.stateful(
        model: WalletResetLimitModel.new,
        sut: -> { WalletResetLimitPbtSupport.sut_factory(-> { WalletResetLimitImpl.new }).call },
        max_steps: 20
      )
    end
  end

  class WalletResetLimitModel
    def initialize
      @commands = [
        ResetToLimitCommand.new
      ]
    end

    def initial_state
      default_state = { balance: 0, credit_limit: 3 } # TODO: replace with a domain-specific structured model state
      WalletResetLimitPbtSupport.initial_state(default_state)
    end

    def commands(_state)
      @commands
    end
  end

  class ResetToLimitCommand
    # Analyzer command confidence: medium
    # TODO: confirm this predicate should be modeled as a command
    def name
      :reset_to_limit
    end

    def arguments
      overridden = WalletResetLimitPbtSupport.call_arguments_override(name)
      return overridden unless overridden.equal?(WalletResetLimitPbtSupport::ARGUMENTS_OVERRIDE_UNSET)
      Pbt.nil
    end

    def applicable?(state)
      override = WalletResetLimitPbtSupport.applicable_override(name)
      return WalletResetLimitPbtSupport.call_applicable_override(override, state, nil) if override
      true
    end

    def next_state(state, args)
      override = WalletResetLimitPbtSupport.next_state_override(name)
      return WalletResetLimitPbtSupport.call_next_state_override(override, state, args) if override
      state.merge(balance: state[:credit_limit])
    end

    def run!(sut, args)
      WalletResetLimitPbtSupport.before_run_hook&.call(sut)
      payload = WalletResetLimitPbtSupport.adapt_args(name, args)
      method_name = WalletResetLimitPbtSupport.resolve_method_name(name, :reset_to_limit)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(WalletResetLimitPbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = WalletResetLimitPbtSupport.adapt_result(name, result)
      WalletResetLimitPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#w'.balance=#w.credit_limit"
      # Analyzer hints: state_field="balance", size_delta=0, transition_kind=nil, requires_non_empty_state=false, scalar_update_kind=:replace_like, command_confidence=:medium, guard_kind=:none, guard_field="balance", guard_constant=nil, rhs_source_kind=:state_field, state_update_shape=:replace_value
      # Related Alloy property predicates: NonNegative
      # Derived verify hints: check_non_negative_scalar_state
      policy = WalletResetLimitPbtSupport.guard_failure_policy(name)
      guard_failed = false
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if WalletResetLimitPbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut,
        guard_failed: guard_failed,
        guard_failure_policy: policy
      )
      observed = WalletResetLimitPbtSupport.observed_state(sut)
      if !observed.nil?
        expected_observed_state = after_state
        raise "Expected observed state to match model" unless observed == expected_observed_state
      end
      # TODO: inferred state field is not collection-like; replace array-based checks with scalar/domain checks
      # Inferred state target: Wallet#balance
      # Derived from related assertions/facts: keep non-negative scalar invariants aligned with the model state
      expected = before_state[:credit_limit]
      raise "Expected replaced value for Wallet#balance" unless after_state[:balance] == expected
      raise "Expected non-negative value for Wallet#balance" unless after_state[:balance] >= 0
      [sut, args] && nil
    end
  end

end