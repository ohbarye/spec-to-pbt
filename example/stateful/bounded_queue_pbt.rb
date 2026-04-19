# frozen_string_literal: true


require_relative "pbt_local"
require "rspec"
require_relative "bounded_queue_impl"
require_relative "bounded_queue_pbt_config"

RSpec.describe "bounded_queue (stateful scaffold)" do
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

    def verify_override(command_name)
      command_config(command_name)[:verify_override]
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
      override.call(**payload)
      true
    end
  end

  it "wires a bounded queue scaffold with capacity-aware overrides" do
    Pbt.assert(worker: :none, num_runs: 5, seed: 1) do
      Pbt.stateful(
        model: BoundedQueueModel.new,
        sut: -> { BoundedQueuePbtSupport.sut_factory(-> { BoundedQueueImpl.new(capacity: 3) }).call },
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
      { elements: [], capacity: 3 }
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
      Pbt.integer
    end

    def applicable?(state)
      override = BoundedQueuePbtSupport.applicable_override(name)
      return BoundedQueuePbtSupport.call_applicable_override(override, state, nil) if override

      state[:elements].length < state[:capacity]
    end

    def next_state(state, args)
      state.merge(elements: state[:elements] + [args])
    end

    def run!(sut, args)
      payload = BoundedQueuePbtSupport.adapt_args(name, args)
      method_name = BoundedQueuePbtSupport.resolve_method_name(name, :enqueue)
      payload.is_a?(Array) ? sut.public_send(method_name, *payload) : sut.public_send(method_name, payload)
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      return nil if BoundedQueuePbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut
      )

      raise "Expected available capacity before enqueue" unless before_state[:elements].length < before_state[:capacity]
      raise "Expected size to increase by 1" unless after_state[:elements].length == before_state[:elements].length + 1
      raise "Expected enqueued element at tail" unless after_state[:elements].last == args
      nil
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
      return BoundedQueuePbtSupport.call_applicable_override(override, state, nil) if override

      !state[:elements].empty?
    end

    def next_state(state, _args)
      state.merge(elements: state[:elements].drop(1))
    end

    def run!(sut, _args)
      method_name = BoundedQueuePbtSupport.resolve_method_name(name, :dequeue)
      sut.public_send(method_name)
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      return nil if BoundedQueuePbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut
      )

      raise "Expected non-empty queue before dequeue" if before_state[:elements].empty?
      raise "Expected dequeued value to match model front" unless result == before_state[:elements].first
      raise "Expected size to decrease by 1" unless after_state[:elements].length == before_state[:elements].length - 1
      nil
    end
  end
end
