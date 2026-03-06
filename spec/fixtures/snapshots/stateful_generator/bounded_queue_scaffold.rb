# frozen_string_literal: true

require "pbt"
require "rspec"
require_relative "bounded_queue_impl"
require_relative "bounded_queue_pbt_config" if File.exist?(File.expand_path("bounded_queue_pbt_config.rb", __dir__))

if File.exist?(File.expand_path("bounded_queue_pbt_config.rb", __dir__)) && !defined?(::BoundedQueuePbtConfig)
  raise "Expected BoundedQueuePbtConfig to be defined in bounded_queue_pbt_config.rb"
end

RSpec.describe "bounded_queue (stateful scaffold)" do
  # Regeneration-safe customization:
  # - edit bounded_queue_pbt_config.rb for SUT wiring and durable API mapping
  # - edit bounded_queue_impl.rb for implementation behavior
  # - edit this scaffold only for one-off refinements when needed

  module BoundedQueuePbtSupport
    module_function

    def config
      defined?(::BoundedQueuePbtConfig) ? ::BoundedQueuePbtConfig : {}
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
      adapter = command_config(command_name)[:arg_adapter]
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
        model: BoundedQueueModel.new,
        sut: -> { BoundedQueuePbtSupport.sut_factory(-> { BoundedQueueImpl.new }).call },
        max_steps: 20
      )
    end
  end

  class BoundedQueueModel
    def initialize
      @commands = [
        EnqueueCommand.new,
        DequeueCommand.new
      ]
    end

    def initial_state
      { elements: [], capacity: 3 } # TODO: replace with a domain-specific structured model state
    end

    def commands(_state)
      @commands
    end
  end

  class EnqueueCommand
    def name
      :enqueue
    end

    def arguments
      Pbt.integer # placeholder for Element
    end

    def applicable?(state)
      override = BoundedQueuePbtSupport.applicable_override(name)
      return override.call(state) if override
      state[:elements].length < state[:capacity] # inferred capacity/fullness guard for enqueue
    end

    def next_state(state, args)
      # Inferred transition target: Queue#elements
      state.merge(elements: state[:elements] + [args])
    end

    def run!(sut, args)
      BoundedQueuePbtSupport.before_run_hook&.call(sut)
      payload = BoundedQueuePbtSupport.adapt_args(name, args)
      method_name = BoundedQueuePbtSupport.resolve_method_name(name, :enqueue)
      result = if payload.nil?
        sut.public_send(method_name)
      elsif payload.is_a?(Array)
        sut.public_send(method_name, *payload)
      else
        sut.public_send(method_name, payload)
      end
      adapted_result = BoundedQueuePbtSupport.adapt_result(name, result)
      BoundedQueuePbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#q.elements<#q.capacity implies#q'.elements=add[#q.elements,1]"
      # Analyzer hints: state_field="elements", size_delta=1, transition_kind=:append, requires_non_empty_state=true, scalar_update_kind=nil, command_confidence=:high, guard_kind=:below_capacity, rhs_source_kind=:unknown, state_update_shape=:append_like
      # Related Alloy assertions: QueueBounds
      # Related Alloy property predicates: EnqueueDequeueIdentity, IsEmpty, IsFull
      # Related pattern hints: size, empty
      # Derived verify hints: respect_non_empty_guard, respect_capacity_guard, check_empty_semantics, check_size_semantics
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if BoundedQueuePbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut
      )
      # Inferred collection target: Queue#elements
      before_items = before_state[:elements]
      after_items = after_state[:elements]
      before_capacity = before_state[:capacity]
      # Derived from related assertions/facts: respect the non-empty guard before removal-style checks
      # Derived from related assertions/facts: respect capacity/fullness guards before append-style checks
      # Derived from related property patterns: verify empty-state semantics for the inferred target
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      raise "Expected available capacity before append" unless before_items.length < before_capacity
      expected_size = before_items.length + 1
      raise "Expected size to increase by 1" unless after_items.length == expected_size
      [sut, args] && nil
    end
  end

  class DequeueCommand
    def name
      :dequeue
    end

    def arguments
      Pbt.nil
    end

    def applicable?(state)
      override = BoundedQueuePbtSupport.applicable_override(name)
      return override.call(state) if override
      !state[:elements].empty? # inferred precondition for dequeue
    end

    def next_state(state, _args)
      # Inferred transition target: Queue#elements
      state.merge(elements: state[:elements].drop(1))
    end

    def run!(sut, args)
      BoundedQueuePbtSupport.before_run_hook&.call(sut)
      payload = BoundedQueuePbtSupport.adapt_args(name, args)
      method_name = BoundedQueuePbtSupport.resolve_method_name(name, :dequeue)
      result = if payload.nil?
        sut.public_send(method_name)
      elsif payload.is_a?(Array)
        sut.public_send(method_name, *payload)
      else
        sut.public_send(method_name, payload)
      end
      adapted_result = BoundedQueuePbtSupport.adapt_result(name, result)
      BoundedQueuePbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#q.elements>0 implies#q'.elements=sub[#q.elements,1]"
      # Analyzer hints: state_field="elements", size_delta=-1, transition_kind=:dequeue, requires_non_empty_state=true, scalar_update_kind=nil, command_confidence=:high, guard_kind=:non_empty, rhs_source_kind=:unknown, state_update_shape=:remove_first
      # Related Alloy assertions: QueueBounds
      # Related Alloy property predicates: EnqueueDequeueIdentity, IsEmpty, IsFull
      # Related pattern hints: size, empty
      # Derived verify hints: respect_non_empty_guard, respect_capacity_guard, check_empty_semantics, check_size_semantics
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if BoundedQueuePbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut
      )
      # Inferred collection target: Queue#elements
      before_items = before_state[:elements]
      after_items = after_state[:elements]
      before_capacity = before_state[:capacity]
      # Derived from related assertions/facts: respect the non-empty guard before removal-style checks
      # Derived from related assertions/facts: respect capacity/fullness guards before append-style checks
      # Derived from related property patterns: verify empty-state semantics for the inferred target
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      raise "Expected non-empty state before removal" if before_items.empty?
      expected = before_state.first
      raise "Expected dequeued value to match model" unless result == expected
      raise "Expected size to decrease by 1" unless after_items.length == before_items.length - 1
      [sut, args] && nil
    end
  end

end