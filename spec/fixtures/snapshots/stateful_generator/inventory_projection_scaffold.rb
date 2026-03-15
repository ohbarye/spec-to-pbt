# frozen_string_literal: true

require "pbt"
require "rspec"
require_relative "inventory_projection_impl"
require_relative "inventory_projection_pbt_config" if File.exist?(File.expand_path("inventory_projection_pbt_config.rb", __dir__))

if File.exist?(File.expand_path("inventory_projection_pbt_config.rb", __dir__)) && !defined?(::InventoryProjectionPbtConfig)
  raise "Expected InventoryProjectionPbtConfig to be defined in inventory_projection_pbt_config.rb"
end

unless Pbt.respond_to?(:stateful)
  loaded_pbt_version = defined?(Gem.loaded_specs) ? Gem.loaded_specs["pbt"]&.version&.to_s : nil
  detail = loaded_pbt_version ? "loaded pbt #{loaded_pbt_version}" : "loaded pbt version unknown"
  raise "Expected pbt >= 0.6.0 with Pbt.stateful (#{detail}). Install a compatible pbt release before running this scaffold."
end

RSpec.describe "inventory_projection (stateful scaffold)" do
  # Regeneration-safe customization:
  # - edit inventory_projection_pbt_config.rb for SUT wiring and durable API mapping
  # - edit inventory_projection_impl.rb for implementation behavior
  # - edit this scaffold only for one-off refinements when needed

  module InventoryProjectionPbtSupport
    module_function
    ARGUMENTS_OVERRIDE_UNSET = Object.new.freeze

    def config
      defined?(::InventoryProjectionPbtConfig) ? ::InventoryProjectionPbtConfig : {}
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
        model: InventoryProjectionModel.new,
        sut: -> { InventoryProjectionPbtSupport.sut_factory(-> { InventoryProjectionImpl.new }).call },
        max_steps: 20
      )
    end
  end

  class InventoryProjectionModel
    def initialize
      @commands = [
        ReceiveCommand.new,
        ShipCommand.new
      ]
    end

    def initial_state
      default_state = { adjustments: [], stock: 0 } # TODO: replace with a domain-specific structured model state
      InventoryProjectionPbtSupport.initial_state(default_state)
    end

    def commands(_state)
      @commands
    end
  end

  class ReceiveCommand
    def name
      :receive
    end

    def arguments
      overridden = InventoryProjectionPbtSupport.call_arguments_override(name)
      return overridden unless overridden.equal?(InventoryProjectionPbtSupport::ARGUMENTS_OVERRIDE_UNSET)
      Pbt.integer
    end

    def applicable?(state)
      override = InventoryProjectionPbtSupport.applicable_override(name)
      return InventoryProjectionPbtSupport.call_applicable_override(override, state, nil) if override
      true
    end

    def next_state(state, args)
      override = InventoryProjectionPbtSupport.next_state_override(name)
      return InventoryProjectionPbtSupport.call_next_state_override(override, state, args) if override
      # Inferred transition target: Inventory#adjustments
      delta = InventoryProjectionPbtSupport.scalar_model_arg(name, args)
      state.merge(adjustments: state[:adjustments] + [delta], stock: state[:stock] + delta)
    end

    def run!(sut, args)
      InventoryProjectionPbtSupport.before_run_hook&.call(sut)
      payload = InventoryProjectionPbtSupport.adapt_args(name, args)
      method_name = InventoryProjectionPbtSupport.resolve_method_name(name, :receive)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(InventoryProjectionPbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = InventoryProjectionPbtSupport.adapt_result(name, result)
      InventoryProjectionPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#i'.adjustments=add[#i.adjustments,1]and#i'.stock=add[#i.stock,amount]"
      # Analyzer hints: state_field="adjustments", size_delta=1, transition_kind=:append, requires_non_empty_state=false, scalar_update_kind=nil, command_confidence=:high, guard_kind=:none, guard_field="adjustments", guard_constant=nil, rhs_source_kind=:unknown, state_update_shape=:append_like
      # Derived verify hints: check_projection_semantics
      policy = InventoryProjectionPbtSupport.guard_failure_policy(name)
      guard_failed = false
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if InventoryProjectionPbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut,
        guard_failed: guard_failed,
        guard_failure_policy: policy
      )
      observed = InventoryProjectionPbtSupport.observed_state(sut)
      if !observed.nil?
        expected_observed_state = after_state
        raise "Expected observed state to match model" unless observed == expected_observed_state
      end
      # Inferred collection target: Inventory#adjustments
      before_items = before_state[:adjustments]
      after_items = after_state[:adjustments]
      # Derived from collection/scalar updates: verify append-only projection semantics against companion scalar fields
      expected_size = before_items.length + 1
      raise "Expected size to increase by 1" unless after_items.length == expected_size
      delta = InventoryProjectionPbtSupport.scalar_model_arg(name, args)
      raise "Expected appended projection entry to match the model delta" unless after_items.last == delta
      before_stock = before_state[:stock]
      after_stock = after_state[:stock]
      raise "Expected incremented value for Inventory#stock" unless after_stock == before_stock + delta
      [sut, args] && nil
    end
  end

  class ShipCommand
    def name
      :ship
    end

    def arguments
      overridden = InventoryProjectionPbtSupport.call_arguments_override(name)
      return overridden unless overridden.equal?(InventoryProjectionPbtSupport::ARGUMENTS_OVERRIDE_UNSET)
      Pbt.integer
    end

    def applicable?(state)
      override = InventoryProjectionPbtSupport.applicable_override(name)
      return InventoryProjectionPbtSupport.call_applicable_override(override, state, nil) if override
      true
    end

    def next_state(state, args)
      override = InventoryProjectionPbtSupport.next_state_override(name)
      return InventoryProjectionPbtSupport.call_next_state_override(override, state, args) if override
      # Inferred transition target: Inventory#adjustments
      delta = InventoryProjectionPbtSupport.scalar_model_arg(name, args)
      state.merge(adjustments: state[:adjustments] + [-delta], stock: state[:stock] - delta)
    end

    def run!(sut, args)
      InventoryProjectionPbtSupport.before_run_hook&.call(sut)
      payload = InventoryProjectionPbtSupport.adapt_args(name, args)
      method_name = InventoryProjectionPbtSupport.resolve_method_name(name, :ship)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(InventoryProjectionPbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = InventoryProjectionPbtSupport.adapt_result(name, result)
      InventoryProjectionPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#i'.adjustments=add[#i.adjustments,1]and#i'.stock=sub[#i.stock,amount]"
      # Analyzer hints: state_field="adjustments", size_delta=1, transition_kind=:append, requires_non_empty_state=false, scalar_update_kind=nil, command_confidence=:high, guard_kind=:none, guard_field="adjustments", guard_constant=nil, rhs_source_kind=:unknown, state_update_shape=:append_like
      # Derived verify hints: check_projection_semantics
      policy = InventoryProjectionPbtSupport.guard_failure_policy(name)
      guard_failed = false
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if InventoryProjectionPbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut,
        guard_failed: guard_failed,
        guard_failure_policy: policy
      )
      observed = InventoryProjectionPbtSupport.observed_state(sut)
      if !observed.nil?
        expected_observed_state = after_state
        raise "Expected observed state to match model" unless observed == expected_observed_state
      end
      # Inferred collection target: Inventory#adjustments
      before_items = before_state[:adjustments]
      after_items = after_state[:adjustments]
      # Derived from collection/scalar updates: verify append-only projection semantics against companion scalar fields
      expected_size = before_items.length + 1
      raise "Expected size to increase by 1" unless after_items.length == expected_size
      delta = InventoryProjectionPbtSupport.scalar_model_arg(name, args)
      raise "Expected appended projection entry to match the model delta" unless after_items.last == -delta
      before_stock = before_state[:stock]
      after_stock = after_state[:stock]
      raise "Expected decremented value for Inventory#stock" unless after_stock == before_stock - delta
      [sut, args] && nil
    end
  end

end