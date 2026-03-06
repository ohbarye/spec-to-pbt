# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path(ENV.fetch("PBT_REPO_DIR", "../../../pbt") + "/lib", __dir__)) if Dir.exist?(File.expand_path(ENV.fetch("PBT_REPO_DIR", "../../../pbt"), __dir__))

require "pbt"
require "rspec"
require_relative "stack_impl"
require_relative "stack_pbt_config" if File.exist?(File.expand_path("stack_pbt_config.rb", __dir__))

if File.exist?(File.expand_path("stack_pbt_config.rb", __dir__)) && !defined?(::StackPbtConfig)
  raise "Expected StackPbtConfig to be defined in stack_pbt_config.rb"
end

RSpec.describe "stack (stateful scaffold)" do
  # Regeneration-safe customization:
  # - edit stack_pbt_config.rb for SUT wiring and durable API mapping
  # - edit stack_impl.rb for implementation behavior
  # - edit this scaffold only for one-off refinements when needed

  module StackPbtSupport
    module_function

    def config
      defined?(::StackPbtConfig) ? ::StackPbtConfig : {}
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
        model: StackModel.new,
        sut: -> { StackPbtSupport.sut_factory(-> { StackImpl.new }).call },
        max_steps: 20
      )
    end
  end

  class StackModel
    def initialize
      @commands = [
        PushAddsElementCommand.new,
        PopRemovesElementCommand.new
      ]
    end

    def initial_state
      []
    end

    def commands(_state)
      @commands
    end
  end

  class PushAddsElementCommand
    def name
      :push_adds_element
    end

    def arguments
      Pbt.integer
    end

    def applicable?(state)
      override = StackPbtSupport.applicable_override(name)
      return override.call(state) if override

      true
    end

    def next_state(state, args)
      state + [args]
    end

    def run!(sut, args)
      StackPbtSupport.before_run_hook&.call(sut)
      payload = StackPbtSupport.adapt_args(name, args)
      method_name = StackPbtSupport.resolve_method_name(name, :push_adds_element)
      result = if payload.nil?
        sut.public_send(method_name)
      elsif payload.is_a?(Array)
        sut.public_send(method_name, *payload)
      else
        sut.public_send(method_name, payload)
      end
      adapted_result = StackPbtSupport.adapt_result(name, result)
      StackPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      return nil if StackPbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut
      )

      expected_size = before_state.length + 1
      raise "Expected size to increase by 1" unless after_state.length == expected_size
      raise "Expected appended argument to become the newest element" unless after_state.last == args
      restored_state = after_state[0...-1]
      raise "Expected append/remove-last roundtrip to restore the previous model state" unless restored_state == before_state
      nil
    end
  end

  class PopRemovesElementCommand
    def name
      :pop_removes_element
    end

    def arguments
      Pbt.nil
    end

    def applicable?(state)
      override = StackPbtSupport.applicable_override(name)
      return override.call(state) if override

      !state.empty?
    end

    def next_state(state, _args)
      state[0...-1]
    end

    def run!(sut, args)
      StackPbtSupport.before_run_hook&.call(sut)
      payload = StackPbtSupport.adapt_args(name, args)
      method_name = StackPbtSupport.resolve_method_name(name, :pop_removes_element)
      result = if payload.nil?
        sut.public_send(method_name)
      elsif payload.is_a?(Array)
        sut.public_send(method_name, *payload)
      else
        sut.public_send(method_name, payload)
      end
      adapted_result = StackPbtSupport.adapt_result(name, result)
      StackPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      return nil if StackPbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut
      )

      raise "Expected non-empty state before removal" if before_state.empty?
      expected = before_state.last
      raise "Expected popped value to match model" unless result == expected
      raise "Expected size to decrease by 1" unless after_state.length == before_state.length - 1
      restored_state = after_state + [result]
      raise "Expected remove-last/append roundtrip to restore the previous model state" unless restored_state == before_state
      nil
    end
  end
end
