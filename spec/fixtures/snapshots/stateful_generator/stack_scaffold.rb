# frozen_string_literal: true

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
      [] # TODO: replace with a domain-specific collection state
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
      Pbt.integer # placeholder for Element
    end

    def applicable?(state)
      override = StackPbtSupport.applicable_override(name)
      return override.call(state) if override
      true
    end

    def next_state(state, args)
      # Inferred transition target: Stack#elements
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
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#s'.elements=add[#s.elements,1]"
      # Analyzer hints: state_field="elements", size_delta=1, transition_kind=:append, requires_non_empty_state=false, scalar_update_kind=nil, command_confidence=:high, guard_kind=:none, rhs_source_kind=:unknown, state_update_shape=:append_like
      # Related Alloy assertions: StackProperties
      # Related Alloy property predicates: PushPopIdentity, IsEmpty, LIFO
      # Related pattern hints: roundtrip, size, empty, ordering
      # Derived verify hints: respect_non_empty_guard, check_empty_semantics, check_ordering_semantics, check_roundtrip_pairing, check_size_semantics
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      if (override = StackPbtSupport.verify_override(name))
        override.call(before_state: before_state, after_state: after_state, args: args, result: result, sut: sut)
        return nil
      end
      # Inferred collection target: Stack#elements
      # Derived from related assertions/facts: respect the non-empty guard before removal-style checks
      # Derived from related property patterns: verify empty-state semantics for the inferred target
      # Derived from related property patterns: verify ordering semantics (for example LIFO/FIFO) where relevant
      # Derived from related property patterns: verify paired-command roundtrip behavior against sibling commands
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      expected_size = before_state.length + 1
      raise "Expected size to increase by 1" unless after_state.length == expected_size
      raise "Expected appended argument to become the newest element" unless after_state.last == args
      restored_state = after_state[0...-1]
      raise "Expected append/remove-last roundtrip to restore the previous model state" unless restored_state == before_state
      [sut, args] && nil
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
      !state.empty? # inferred precondition for pop_removes_element
    end

    def next_state(state, _args)
      # Inferred transition target: Stack#elements
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
      # TODO: translate predicate semantics into postcondition checks
      # Alloy predicate body (preview): "#s.elements>0 implies#s'.elements=sub[#s.elements,1]"
      # Analyzer hints: state_field="elements", size_delta=-1, transition_kind=:pop, requires_non_empty_state=true, scalar_update_kind=nil, command_confidence=:high, guard_kind=:non_empty, rhs_source_kind=:unknown, state_update_shape=:remove_last
      # Related Alloy assertions: StackProperties
      # Related Alloy property predicates: PushPopIdentity, IsEmpty, LIFO
      # Related pattern hints: roundtrip, size, empty, ordering
      # Derived verify hints: respect_non_empty_guard, check_empty_semantics, check_ordering_semantics, check_roundtrip_pairing, check_size_semantics
      # Suggested verify order:
      # 1. Command-specific postconditions
      # 2. Related Alloy assertions/facts
      # 3. Related property predicates
      if (override = StackPbtSupport.verify_override(name))
        override.call(before_state: before_state, after_state: after_state, args: args, result: result, sut: sut)
        return nil
      end
      # Inferred collection target: Stack#elements
      # Derived from related assertions/facts: respect the non-empty guard before removal-style checks
      # Derived from related property patterns: verify empty-state semantics for the inferred target
      # Derived from related property patterns: verify ordering semantics (for example LIFO/FIFO) where relevant
      # Derived from related property patterns: verify paired-command roundtrip behavior against sibling commands
      # Derived from related property patterns: keep size-change checks aligned with related assertions/facts
      raise "Expected non-empty state before removal" if before_state.empty?
      expected = before_state.last
      raise "Expected popped value to match model" unless result == expected
      raise "Expected size to decrease by 1" unless after_state.length == before_state.length - 1
      restored_state = after_state + [result]
      raise "Expected remove-last/append roundtrip to restore the previous model state" unless restored_state == before_state
      [sut, args] && nil
    end
  end

end