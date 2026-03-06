# frozen_string_literal: true

require "pbt"
require "rspec"
require_relative "bag_impl"
require_relative "bag_pbt_config" if File.exist?(File.expand_path("bag_pbt_config.rb", __dir__))

if File.exist?(File.expand_path("bag_pbt_config.rb", __dir__)) && !defined?(::BagPbtConfig)
  raise "Expected BagPbtConfig to be defined in bag_pbt_config.rb"
end

RSpec.describe "bag (stateful scaffold)" do
  # Regeneration-safe customization:
  # - edit bag_pbt_config.rb for SUT wiring and durable API mapping
  # - edit bag_impl.rb for implementation behavior
  # - edit this scaffold only for one-off refinements when needed

  module BagPbtSupport
    module_function

    def config
      defined?(::BagPbtConfig) ? ::BagPbtConfig : {}
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
        model: BagModel.new,
        sut: -> { BagPbtSupport.sut_factory(-> { BagImpl.new }).call },
        max_steps: 20
      )
    end
  end

  class BagModel
    def initialize
      @commands = [
        DropLastCommand.new
      ]
    end

    def initial_state
      [] # TODO: replace with a domain-specific collection state
    end

    def commands(_state)
      @commands
    end
  end

  class DropLastCommand
    def name
      :drop_last
    end

    def arguments
      Pbt.nil
    end

    def applicable?(state)
      override = BagPbtSupport.applicable_override(name)
      return override.call(state) if override
      !state.empty? # inferred precondition for drop_last
    end

    def next_state(state, _args)
      # Inferred transition target: Bag#elems
      state[0...-1]
    end

    def run!(sut, args)
      BagPbtSupport.before_run_hook&.call(sut)
      payload = BagPbtSupport.adapt_args(name, args)
      method_name = BagPbtSupport.resolve_method_name(name, :drop_last)
      result = if payload.nil?
        sut.public_send(method_name)
      elsif payload.is_a?(Array)
        sut.public_send(method_name, *payload)
      else
        sut.public_send(method_name, payload)
      end
      adapted_result = BagPbtSupport.adapt_result(name, result)
      BagPbtSupport.after_run_hook&.call(sut, adapted_result)
      adapted_result
    end

    def verify!(before_state:, after_state:, args:, result:, sut:)
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#b.elems>0 implies#b'.elems=sub[#b.elems,1]"
      # Analyzer hints: state_field="elems", size_delta=-1, transition_kind=:pop, requires_non_empty_state=true, scalar_update_kind=nil, command_confidence=:high, guard_kind=:non_empty, rhs_source_kind=:unknown, state_update_shape=:remove_last
      # Derived verify hints: respect_non_empty_guard
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      return nil if BagPbtSupport.call_verify_override(
        name,
        before_state: before_state,
        after_state: after_state,
        args: args,
        result: result,
        sut: sut
      )
      # Inferred collection target: Bag#elems
      # Derived from related assertions/facts: respect the non-empty guard before removal-style checks
      raise "Expected non-empty state before removal" if before_state.empty?
      expected = before_state.last
      raise "Expected popped value to match model" unless result == expected
      raise "Expected size to decrease by 1" unless after_state.length == before_state.length - 1
      [sut, args] && nil
    end
  end

end