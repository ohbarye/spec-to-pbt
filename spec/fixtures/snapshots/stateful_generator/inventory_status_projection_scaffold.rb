# frozen_string_literal: true

require "pbt"
require "rspec"
require_relative "inventory_status_projection_impl"
require_relative "inventory_status_projection_pbt_config" if File.exist?(File.expand_path("inventory_status_projection_pbt_config.rb", __dir__))

if File.exist?(File.expand_path("inventory_status_projection_pbt_config.rb", __dir__)) && !defined?(::InventoryStatusProjectionPbtConfig)
  raise "Expected InventoryStatusProjectionPbtConfig to be defined in inventory_status_projection_pbt_config.rb"
end

RSpec.describe "inventory_status_projection (stateful scaffold)" do
  # Regeneration-safe customization:
  # - edit inventory_status_projection_pbt_config.rb for SUT wiring and durable API mapping
  # - edit inventory_status_projection_impl.rb for implementation behavior
  # - edit this scaffold only for one-off refinements when needed

  module InventoryStatusProjectionPbtSupport
    module_function

    def config
      defined?(::InventoryStatusProjectionPbtConfig) ? ::InventoryStatusProjectionPbtConfig : {}
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
        model: InventoryStatusProjectionModel.new,
        sut: -> { InventoryStatusProjectionPbtSupport.sut_factory(-> { InventoryStatusProjectionImpl.new }).call },
        max_steps: 20
      )
    end
  end

  class InventoryStatusProjectionModel
    def initialize
      @commands = [
        ActivateCommand.new,
        ReceiveCommand.new,
        DeactivateCommand.new
      ]
    end

    def initial_state
      default_state = { movements: [], status: 0, stock: 0 } # TODO: replace with a domain-specific structured model state
      InventoryStatusProjectionPbtSupport.initial_state(default_state)
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
      Pbt.nil
    end

    def applicable?(state)
      override = InventoryStatusProjectionPbtSupport.applicable_override(name)
      return InventoryStatusProjectionPbtSupport.call_applicable_override(override, state, nil) if override
      return true if InventoryStatusProjectionPbtSupport.guard_failure_policy(name)
      guard_satisfied?(state)
    end

    def guard_satisfied?(state, _args = nil)
      state[:status] == 0 # inferred structured collection/status precondition for activate
    end

    def next_state(state, args)
      override = InventoryStatusProjectionPbtSupport.next_state_override(name)
      return InventoryStatusProjectionPbtSupport.call_next_state_override(override, state, args) if override
      return state if InventoryStatusProjectionPbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      # Inferred transition target: Inventory#movements
      state.merge(movements: state[:movements], status: 1, stock: state[:stock])
    end

    def run!(sut, args)
      InventoryStatusProjectionPbtSupport.before_run_hook&.call(sut)
      payload = InventoryStatusProjectionPbtSupport.adapt_args(name, args)
      method_name = InventoryStatusProjectionPbtSupport.resolve_method_name(name, :activate)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(InventoryStatusProjectionPbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = InventoryStatusProjectionPbtSupport.adapt_result(name, result)
      InventoryStatusProjectionPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#i.status=0 implies#i'.status=1 and#i'.movements=#i.movements and#i'.stock=#i.stock"
      # Analyzer hints: state_field="movements", size_delta=0, transition_kind=:size_no_change, requires_non_empty_state=false, scalar_update_kind=nil, command_confidence=:medium, guard_kind=:state_equals_constant, guard_field="status", guard_constant="0", rhs_source_kind=:constant, state_update_shape=:preserve_size
      # Derived verify hints: check_guard_failure_semantics
      policy = InventoryStatusProjectionPbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if InventoryStatusProjectionPbtSupport.call_verify_override(
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
        observed = InventoryStatusProjectionPbtSupport.observed_state(sut)
        case policy
        when :no_op
          raise "Expected unchanged model state on guard failure" unless after_state == before_state
          raise "Expected unchanged observed state on guard failure" if !observed.nil? && observed != after_state[:movements]
        when :raise
          raise "Expected guard failure to surface as an exception" unless result.is_a?(StandardError)
          raise "Expected unchanged model state on guard failure" unless after_state == before_state
          raise "Expected unchanged observed state on guard failure" if !observed.nil? && observed != after_state[:movements]
        when :custom
          raise "guard_failure_policy :custom requires verify_override to assert invalid-path semantics"
        else
          raise "Unsupported guard_failure_policy: #{policy.inspect}"
        end
        return nil
      end
      # Inferred collection target: Inventory#movements
      before_items = before_state[:movements]
      after_items = after_state[:movements]
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      raise "Expected size to stay the same" unless after_items.length == before_items.length
      before_status = before_state[:status]
      after_status = after_state[:status]
      expected_status = 1
      raise "Expected replaced value for Inventory#status" unless after_status == expected_status
      before_stock = before_state[:stock]
      after_stock = after_state[:stock]
      raise "Expected preserved value for Inventory#stock" unless after_stock == before_stock
      # TODO: add concrete collection checks for Activate
      [sut, args] && nil
    end
  end

  class ReceiveCommand
    def name
      :receive
    end

    def arguments
      Pbt.integer
    end

    def applicable?(state)
      override = InventoryStatusProjectionPbtSupport.applicable_override(name)
      return InventoryStatusProjectionPbtSupport.call_applicable_override(override, state, nil) if override
      return true if InventoryStatusProjectionPbtSupport.guard_failure_policy(name)
      guard_satisfied?(state)
    end

    def guard_satisfied?(state, _args = nil)
      state[:status] == 1 # inferred structured collection/status precondition for receive
    end

    def next_state(state, args)
      override = InventoryStatusProjectionPbtSupport.next_state_override(name)
      return InventoryStatusProjectionPbtSupport.call_next_state_override(override, state, args) if override
      return state if InventoryStatusProjectionPbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      # Inferred transition target: Inventory#movements
      delta = InventoryStatusProjectionPbtSupport.scalar_model_arg(name, args)
      state.merge(movements: state[:movements] + [delta], status: state[:status], stock: state[:stock] + delta)
    end

    def run!(sut, args)
      InventoryStatusProjectionPbtSupport.before_run_hook&.call(sut)
      payload = InventoryStatusProjectionPbtSupport.adapt_args(name, args)
      method_name = InventoryStatusProjectionPbtSupport.resolve_method_name(name, :receive)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(InventoryStatusProjectionPbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = InventoryStatusProjectionPbtSupport.adapt_result(name, result)
      InventoryStatusProjectionPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#i.status=1 implies#i'.status=#i.status and#i'.movements=add[#i.movements,1]and#i'.stock=add[#i.stock,amount]"
      # Analyzer hints: state_field="movements", size_delta=1, transition_kind=:append, requires_non_empty_state=false, scalar_update_kind=nil, command_confidence=:high, guard_kind=:state_equals_constant, guard_field="status", guard_constant="1", rhs_source_kind=:state_field, state_update_shape=:append_like
      # Derived verify hints: check_projection_semantics, check_guard_failure_semantics
      policy = InventoryStatusProjectionPbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if InventoryStatusProjectionPbtSupport.call_verify_override(
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
        observed = InventoryStatusProjectionPbtSupport.observed_state(sut)
        case policy
        when :no_op
          raise "Expected unchanged model state on guard failure" unless after_state == before_state
          raise "Expected unchanged observed state on guard failure" if !observed.nil? && observed != after_state[:movements]
        when :raise
          raise "Expected guard failure to surface as an exception" unless result.is_a?(StandardError)
          raise "Expected unchanged model state on guard failure" unless after_state == before_state
          raise "Expected unchanged observed state on guard failure" if !observed.nil? && observed != after_state[:movements]
        when :custom
          raise "guard_failure_policy :custom requires verify_override to assert invalid-path semantics"
        else
          raise "Unsupported guard_failure_policy: #{policy.inspect}"
        end
        return nil
      end
      # Inferred collection target: Inventory#movements
      before_items = before_state[:movements]
      after_items = after_state[:movements]
      # Derived from collection/scalar updates: verify append-only projection semantics against companion scalar fields
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      expected_size = before_items.length + 1
      raise "Expected size to increase by 1" unless after_items.length == expected_size
      delta = InventoryStatusProjectionPbtSupport.scalar_model_arg(name, args)
      raise "Expected appended projection entry to match the model delta" unless after_items.last == delta
      before_status = before_state[:status]
      after_status = after_state[:status]
      raise "Expected preserved value for Inventory#status" unless after_status == before_status
      before_stock = before_state[:stock]
      after_stock = after_state[:stock]
      raise "Expected incremented value for Inventory#stock" unless after_stock == before_stock + delta
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
      Pbt.nil
    end

    def applicable?(state)
      override = InventoryStatusProjectionPbtSupport.applicable_override(name)
      return InventoryStatusProjectionPbtSupport.call_applicable_override(override, state, nil) if override
      return true if InventoryStatusProjectionPbtSupport.guard_failure_policy(name)
      guard_satisfied?(state)
    end

    def guard_satisfied?(state, _args = nil)
      state[:status] == 1 # inferred structured collection/status precondition for deactivate
    end

    def next_state(state, args)
      override = InventoryStatusProjectionPbtSupport.next_state_override(name)
      return InventoryStatusProjectionPbtSupport.call_next_state_override(override, state, args) if override
      return state if InventoryStatusProjectionPbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)
      # Inferred transition target: Inventory#movements
      state.merge(movements: state[:movements], status: 2, stock: state[:stock])
    end

    def run!(sut, args)
      InventoryStatusProjectionPbtSupport.before_run_hook&.call(sut)
      payload = InventoryStatusProjectionPbtSupport.adapt_args(name, args)
      method_name = InventoryStatusProjectionPbtSupport.resolve_method_name(name, :deactivate)
      result = begin
        if payload.nil?
          sut.public_send(method_name)
        elsif payload.is_a?(Array)
          sut.public_send(method_name, *payload)
        else
          sut.public_send(method_name, payload)
        end
      rescue StandardError => error
        raise unless [:raise, :custom].include?(InventoryStatusProjectionPbtSupport.guard_failure_policy(name))
        error
      end
      adapted_result = InventoryStatusProjectionPbtSupport.adapt_result(name, result)
      InventoryStatusProjectionPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#i.status=1 implies#i'.status=2 and#i'.movements=#i.movements and#i'.stock=#i.stock"
      # Analyzer hints: state_field="movements", size_delta=0, transition_kind=:size_no_change, requires_non_empty_state=false, scalar_update_kind=nil, command_confidence=:medium, guard_kind=:state_equals_constant, guard_field="status", guard_constant="1", rhs_source_kind=:constant, state_update_shape=:preserve_size
      # Derived verify hints: check_guard_failure_semantics
      policy = InventoryStatusProjectionPbtSupport.guard_failure_policy(name)
      guard_failed = policy && !guard_satisfied?(before_state, args)
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if InventoryStatusProjectionPbtSupport.call_verify_override(
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
        observed = InventoryStatusProjectionPbtSupport.observed_state(sut)
        case policy
        when :no_op
          raise "Expected unchanged model state on guard failure" unless after_state == before_state
          raise "Expected unchanged observed state on guard failure" if !observed.nil? && observed != after_state[:movements]
        when :raise
          raise "Expected guard failure to surface as an exception" unless result.is_a?(StandardError)
          raise "Expected unchanged model state on guard failure" unless after_state == before_state
          raise "Expected unchanged observed state on guard failure" if !observed.nil? && observed != after_state[:movements]
        when :custom
          raise "guard_failure_policy :custom requires verify_override to assert invalid-path semantics"
        else
          raise "Unsupported guard_failure_policy: #{policy.inspect}"
        end
        return nil
      end
      # Inferred collection target: Inventory#movements
      before_items = before_state[:movements]
      after_items = after_state[:movements]
      # Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged
      raise "Expected size to stay the same" unless after_items.length == before_items.length
      before_status = before_state[:status]
      after_status = after_state[:status]
      expected_status = 2
      raise "Expected replaced value for Inventory#status" unless after_status == expected_status
      before_stock = before_state[:stock]
      after_stock = after_state[:stock]
      raise "Expected preserved value for Inventory#stock" unless after_stock == before_stock
      # TODO: add concrete collection checks for Deactivate
      [sut, args] && nil
    end
  end

end