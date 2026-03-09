# frozen_string_literal: true

require "spec_helper"

RSpec.describe SpecToPbt::StatefulGenerator do
  describe "#generate" do
    let(:generator) { described_class.new(spec) }

    context "with stack spec" do
      let(:fixture_path) { File.expand_path("../fixtures/alloy/stack.als", __dir__) }
      let(:source) { File.read(fixture_path) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "generates valid Ruby code" do
        code = generator.generate
        expect { RubyVM::InstructionSequence.compile(code) }.not_to raise_error
      end

      it "generates a stateful PBT entrypoint" do
        code = generator.generate

        expect(code).to include("Pbt.stateful(")
        expect(code).to include("worker: :none")
        expect(code).to include('ENV["ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD"]')
        expect(code).to include('require_relative "stack_pbt_config" if File.exist?')
        expect(code).to include("edit stack_pbt_config.rb for SUT wiring and durable API mapping")
        expect(code).to include("default_state = [] # TODO: replace with a domain-specific collection state")
        expect(code).to include("StackPbtSupport.initial_state(default_state)")
      end

      it "generates a model class for the module" do
        code = generator.generate

        expect(code).to include("class StackModel")
        expect(code).to include("def initial_state")
        expect(code).to include("def commands(_state)")
      end

      it "extracts command predicates and excludes property-like predicates" do
        code = generator.generate

        expect(code).to include("class PushAddsElementCommand")
        expect(code).to include("class PopRemovesElementCommand")
        expect(code).not_to include("class PushPopIdentityCommand")
        expect(code).not_to include("class LIFOCommand")
      end

      it "infers argument arbitraries for command parameters" do
        code = generator.generate

        expect(code).to include("Pbt.integer # placeholder for Element")
        expect(code).to include("def arguments\n      Pbt.nil\n    end")
        expect(code).to include("resolve_method_name(name, :push_adds_element)")
      end

      it "generates more concrete preconditions and postconditions for common commands" do
        code = generator.generate

        expect(code).to include("!state.empty? # inferred precondition for pop_removes_element")
        expect(code).to include("Expected size to increase by 1")
        expect(code).to include("Expected appended argument to become the newest element")
        expect(code).to include("Expected append/remove-last roundtrip to restore the previous model state")
        expect(code).to include("Expected popped value to match model")
        expect(code).to include("Expected remove-last/append roundtrip to restore the previous model state")
        expect(code).to include("Inferred collection target: Stack#elements")
        expect(code).to include("adapt_args(name, args)")
        expect(code).to include("adapter = settings[:arg_adapter] || settings[:model_arg_adapter]")
        expect(code).to include("scalar_model_arg(command_name, args)")
        expect(code).to include("call_verify_override(")
        expect(code).to include("observed_state(sut)")
      end

      it "adds assertion/fact hints to verify! comments" do
        code = generator.generate

        expect(code).to include("# Related Alloy assertions: StackProperties")
        expect(code).to include("# Related pattern hints:")
        expect(code).to include("# Derived verify hints:")
        expect(code).to include("empty")
      end

      it "adds sibling property predicate hints for the same state domain" do
        code = generator.generate

        expect(code).to include("# Related Alloy property predicates: PushPopIdentity, IsEmpty, LIFO")
        expect(code).to include("# Related pattern hints:")
        expect(code).to include("verify paired-command roundtrip behavior against sibling commands")
        expect(code).to include("verify ordering semantics (for example LIFO/FIFO) where relevant")
        expect(code).to include("roundtrip")
        expect(code).to include("empty")
        expect(code).to include("ordering")
      end
    end

    context "with queue spec" do
      let(:fixture_path) { File.expand_path("../fixtures/alloy/queue.als", __dir__) }
      let(:source) { File.read(fixture_path) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "extracts enqueue/dequeue commands and excludes ordering properties" do
        code = generator.generate

        expect(code).to include("class EnqueueCommand")
        expect(code).to include("class DequeueCommand")
        expect(code).not_to include("class EnqueueDequeueIdentityCommand")
        expect(code).not_to include("class FIFOCommand")
        expect(code).to include("state.drop(1)")
        expect(code).to include("Expected dequeued value to match model")
        expect(code).to include("Expected appended argument to become the newest element")
        expect(code).not_to include("append/remove-last roundtrip to restore the previous model state")
        expect(code).to include("# Related Alloy property predicates: EnqueueDequeueIdentity, IsEmpty, FIFO")
        expect(code).to include("# Related pattern hints:")
        expect(code).to include("respect the non-empty guard before removal-style checks")
        expect(code).to include("empty")
        expect(code).to include("ordering")
      end
    end

    context "with bounded queue spec" do
      let(:fixture_path) { File.expand_path("../fixtures/alloy/bounded_queue.als", __dir__) }
      let(:source) { File.read(fixture_path) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "surfaces capacity/fullness guard guidance for enqueue-like commands" do
        code = generator.generate

        expect(code).to include("{ elements: [], capacity: 3 } # TODO: replace with a domain-specific structured model state")
        expect(code).to include("state[:elements].length < state[:capacity] # inferred capacity/fullness guard for enqueue")
        expect(code).to include("state.merge(elements: state[:elements] + [args])")
        expect(code).to include("Related Alloy property predicates: EnqueueDequeueIdentity, IsEmpty, IsFull")
        expect(code).to include("respect capacity/fullness guards before append-style checks")
        expect(code).to include("before_items = before_state[:elements]")
        expect(code).to include("before_capacity = before_state[:capacity]")
      end
    end

    context "with sort spec (no command-like predicates)" do
      let(:fixture_path) { File.expand_path("../fixtures/alloy/sort.als", __dir__) }
      let(:source) { File.read(fixture_path) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "emits a placeholder command scaffold" do
        code = generator.generate

        expect(code).to include("GeneratedCommand.new")
        expect(code).to include("class GeneratedCommand")
      end
    end

    context "with primed state params on a non-module state signature" do
      let(:source) do
        <<~ALLOY
          module workflow

          sig Machine {
            value: one Int
          }

          sig Token {}

          pred Step[m, m': Machine, t: Token] {
            #m'.value = add[#m.value, 1]
          }
        ALLOY
      end
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "excludes primed state parameter pairs from command arguments" do
        code = generator.generate

        expect(code).to include("class StepCommand")
        expect(code).to include("def arguments\n      Pbt.integer # placeholder for Token\n    end")
        expect(code).to include("0 # TODO: replace with a domain-specific scalar model state")
        expect(code).not_to include("Pbt.tuple(")
        expect(code).to include("def next_state(state, args)\n      override = WorkflowPbtSupport.next_state_override(name)\n      return WorkflowPbtSupport.call_next_state_override(override, state, args) if override\n      state + 1")
        expect(code).not_to include("state + [args]")
      end
    end

    context "with facts that reference a command predicate" do
      let(:source) do
        <<~ALLOY
          module ledger

          sig Ledger { size: one Int }
          sig Entry {}

          pred Append[l, l': Ledger, e: Entry] {
            #l'.size = add[#l.size, 1]
          }

          fact LedgerInvariant {
            all l, l': Ledger, e: Entry | Append[l, l', e]
          }
        ALLOY
      end
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "includes related fact names in verify! hints" do
        code = generator.generate

        expect(code).to include("# Related Alloy facts: LedgerInvariant")
      end
    end

    context "with a size-preserving command-like transition" do
      let(:source) do
        <<~ALLOY
          module cache

          sig Cache {
            entries: seq Int
          }

          pred Rewrite[c, c': Cache] {
            #c'.entries = #c.entries
          }
        ALLOY
      end
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "emits analyzer hints and a generic size-preserving verify scaffold" do
        code = generator.generate

        expect(code).to include('transition_kind=:size_no_change')
        expect(code).to include('state_update_shape=:preserve_size')
        expect(code).to include("Expected size to stay the same")
      end
    end

    context "with a scalar state field" do
      let(:source) do
        <<~ALLOY
          module workflow

          sig Machine {
            value: one Int
          }

          sig Token {}

          pred Step[m, m': Machine, t: Token] {
            #m'.value = add[#m.value, 1]
          }
        ALLOY
      end
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "mentions the inferred state field in scalar verify guidance" do
        code = generator.generate

        expect(code).to include('state_field="value"')
        expect(code).to include("replace array-based checks with scalar/domain checks")
        expect(code).to include("Inferred state target: Machine#value")
        expect(code).to include("0 # TODO: replace with a domain-specific scalar model state")
        expect(code).to include("before_value = before_state")
        expect(code).to include("after_value = after_state")
        expect(code).to include('raise "Expected incremented value for Machine#value" unless after_value == before_value + 1')
        expect(code).to include("state_update_shape=:increment")
      end
    end

    context "with bank-account style amount updates" do
      let(:fixture_path) { File.expand_path("../fixtures/alloy/bank_account.als", __dir__) }
      let(:source) { File.read(fixture_path) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "emits scalar arg-aware next_state and verify guidance" do
        code = generator.generate

        expect(code).to include("default_state = 0 # TODO: replace with a domain-specific scalar model state")
        expect(code).to include("BankAccountPbtSupport.initial_state(default_state)")
        expect(code).to include("class DepositAmountCommand")
        expect(code).to include("delta = BankAccountPbtSupport.scalar_model_arg(name, args)")
        expect(code).to include("state + delta")
        expect(code).to include("Expected incremented value for Account#balance")
        expect(code).to include("class WithdrawAmountCommand")
        expect(code).to include("def arguments(state)")
        expect(code).to include("Pbt.integer(min: 1, max: state)")
        expect(code).to include("def applicable?(state, args)")
        expect(code).to include("return BankAccountPbtSupport.call_applicable_override(override, state, args) if override")
        expect(code).to include("return true if BankAccountPbtSupport.guard_failure_policy(name)")
        expect(code).to include("def guard_satisfied?(state, args = nil)")
        expect(code).to include("delta = BankAccountPbtSupport.scalar_model_arg(name, args)")
        expect(code).to include("current_value = state")
        expect(code).to include("delta.is_a?(Numeric) && delta.positive? && delta <= current_value")
        expect(code).to include("return state if BankAccountPbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)")
        expect(code).to include("state - delta")
        expect(code).to include("policy = BankAccountPbtSupport.guard_failure_policy(name)")
        expect(code).to include("guard_failed = policy && !guard_satisfied?(before_state, args)")
        expect(code).to include("guard_failed: guard_failed,")
        expect(code).to include("guard_failure_policy: policy")
        expect(code).to include('raise "Expected unchanged model state on guard failure" unless after_state == before_state')
        expect(code).to include('raise "Expected guard failure to surface as an exception" unless result.is_a?(StandardError)')
        expect(code).to include('raise "guard_failure_policy :custom requires verify_override to assert invalid-path semantics"')
        expect(code).to include("Expected decremented value for Account#balance")
        expect(code).to include("Expected sufficient scalar state before decrement")
        expect(code).to include("Expected non-negative value for Account#balance")
      end

      it "emits fixed +1/-1 scalar transitions for no-arg balance updates" do
        code = generator.generate

        expect(code).to include("class DepositCommand")
        expect(code).to include("def applicable?(state)")
        expect(code).to include("state > 0 # inferred scalar precondition for withdraw")
        expect(code).to include("def next_state(state, args)\n      override = BankAccountPbtSupport.next_state_override(name)\n      return BankAccountPbtSupport.call_next_state_override(override, state, args) if override\n      state + 1")
        expect(code).to include("raise \"Expected incremented value for Account#balance\" unless after_value == before_value + 1")
        expect(code).to include("def next_state(state, args)\n      override = BankAccountPbtSupport.next_state_override(name)\n      return BankAccountPbtSupport.call_next_state_override(override, state, args) if override\n      return state if BankAccountPbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)\n      state - 1")
        expect(code).to include("raise \"Expected decremented value for Account#balance\" unless after_value == before_value - 1")
      end
    end

    context "with scalar state plus a stable companion limit field" do
      let(:fixture_path) { File.expand_path("../fixtures/alloy/wallet_with_limit.als", __dir__) }
      let(:source) { File.read(fixture_path) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "generates a structured scalar model and field-aware updates" do
        code = generator.generate

        expect(code).to include("default_state = { balance: 0, credit_limit: 3 } # TODO: replace with a domain-specific structured model state")
        expect(code).to include("default_state = { balance: 0, credit_limit: 3 } # TODO: replace with a domain-specific structured model state")
        expect(code).to include("WalletWithLimitPbtSupport.initial_state(default_state)")
        expect(code).to include("state[:balance] > 0 # inferred scalar precondition for withdraw")
        expect(code).to include("state.merge(balance: state[:balance] + 1)")
        expect(code).to include("state.merge(balance: state[:balance] - 1)")
        expect(code).to include("before_value = before_state[:balance]")
        expect(code).to include("after_value = after_state[:balance]")
        expect(code).to include('raise "Expected non-negative value for Wallet#balance" unless after_state[:balance] >= 0')
      end
    end

    context "with a replace-like scalar state update" do
      let(:source) do
        <<~ALLOY
          module thermostat

          sig Thermostat {
            target: one Int
          }

          pred SetTarget[t, t': Thermostat, next: Int] {
            #t'.target = #next
          }
        ALLOY
      end
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "emits replacement-oriented scalar guidance" do
        code = generator.generate

        expect(code).to include("0 # TODO: replace with a domain-specific scalar model state")
        expect(code).to include('rhs_source_kind=:arg')
        expect(code).to include('state_update_shape=:replace_with_arg')
        expect(code).to include("Expected replaced value for Thermostat#target")
      end
    end

    context "with membership-oriented queue properties" do
      let(:fixture_path) { File.expand_path("../fixtures/alloy/membership_queue.als", __dir__) }
      let(:source) { File.read(fixture_path) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "adds safe membership checks for append-like transitions" do
        code = generator.generate

        expect(code).to include("Related Alloy property predicates: EnqueueContains")
        expect(code).to include("Derived verify hints: check_membership_semantics")
        expect(code).to include("verify membership semantics for appended/removed elements where safe")
        expect(code).to include('raise "Expected appended argument to be present in model state" unless after_items.include?(args)')
      end
    end

    context "with a decrement-like scalar state update" do
      let(:source) do
        <<~ALLOY
          module counter

          sig Counter {
            value: one Int
          }

          pred Dec[c, c': Counter] {
            #c'.value = sub[#c.value, 1]
          }
        ALLOY
      end
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "emits decrement-oriented scalar guidance" do
        code = generator.generate

        expect(code).to include('state_update_shape=:decrement')
        expect(code).to include("def next_state(state, args)\n      override = CounterPbtSupport.next_state_override(name)\n      return CounterPbtSupport.call_next_state_override(override, state, args) if override\n      state - 1")
        expect(code).to include('raise "Expected decremented value for Counter#value" unless after_value == before_value - 1')
      end
    end

    context "with a preserve-value scalar state update" do
      let(:source) do
        <<~ALLOY
          module box

          sig Box {
            value: one Int
          }

          pred Keep[b, b': Box] {
            #b'.value = #b.value
          }
        ALLOY
      end
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "emits preserve-value scalar guidance" do
        code = generator.generate

        expect(code).to include("0 # TODO: replace with a domain-specific scalar model state")
        expect(code).to include('state_update_shape=:preserve_value')
        expect(code).to include("keep Box#value stable unless other domain state changes")
        expect(code).to include('raise "Expected preserved value for Box#value" unless after_state == before_state')
      end
    end

    context "with a replace-value scalar state update sourced from another state field" do
      let(:fixture_path) { File.expand_path("../fixtures/alloy/wallet_reset_limit.als", __dir__) }
      let(:source) { File.read(fixture_path) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "generates field-aware next_state and verify checks" do
        code = generator.generate

        expect(code).to include("default_state = { balance: 0, credit_limit: 3 } # TODO: replace with a domain-specific structured model state")
        expect(code).to include("WalletResetLimitPbtSupport.initial_state(default_state)")
        expect(code).to include("def next_state(state, args)\n      override = WalletResetLimitPbtSupport.next_state_override(name)\n      return WalletResetLimitPbtSupport.call_next_state_override(override, state, args) if override\n      state.merge(balance: state[:credit_limit])")
        expect(code).to include("expected = before_state[:credit_limit]")
        expect(code).to include('raise "Expected replaced value for Wallet#balance" unless after_state[:balance] == expected')
        expect(code).to include('raise "Expected non-negative value for Wallet#balance" unless after_state[:balance] >= 0')
      end
    end

    context "with hold/capture/release reservation transitions" do
      let(:fixture_path) { File.expand_path("../fixtures/alloy/hold_capture_release.als", __dir__) }
      let(:source) { File.read(fixture_path) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "generates multi-field structured scalar updates and checks" do
        code = generator.generate

        expect(code).to include("default_state = { available: 0, held: 0 } # TODO: replace with a domain-specific structured model state")
        expect(code).to include("default_state = { available: 0, held: 0 } # TODO: replace with a domain-specific structured model state")
        expect(code).to include("HoldCaptureReleasePbtSupport.initial_state(default_state)")
        expect(code).to include("def arguments(state)\n      Pbt.integer(min: 1, max: state[:available])\n    end")
        expect(code).to include("class ReleaseCommand")
        expect(code).to include("def arguments(state)\n      Pbt.integer(min: 1, max: state[:held])\n    end")
        expect(code).to include("current_value = state[:held]")
        expect(code).to include("state.merge(available: state[:available] - delta, held: state[:held] + delta)")
        expect(code).to include("state.merge(available: state[:available] + delta, held: state[:held] - delta)")
        expect(code).to include("Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged")
        expect(code).to include('raise "Expected incremented value for Reservation#held" unless after_held == before_held + delta')
        expect(code).to include('raise "Expected decremented value for Reservation#available" unless after_available == before_available - delta')
        expect(code).to include('raise "Expected total scalar value to stay the same" unless after_available + after_held == before_available + before_held')
      end
    end

    context "with transfer-between-accounts transitions" do
      let(:fixture_path) { File.expand_path("../fixtures/alloy/transfer_between_accounts.als", __dir__) }
      let(:source) { File.read(fixture_path) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "generates transfer-style paired balance checks" do
        code = generator.generate

        expect(code).to include("default_state = { source_balance: 0, target_balance: 0 } # TODO: replace with a domain-specific structured model state")
        expect(code).to include("default_state = { source_balance: 0, target_balance: 0 } # TODO: replace with a domain-specific structured model state")
        expect(code).to include("TransferBetweenAccountsPbtSupport.initial_state(default_state)")
        expect(code).to include("def arguments(state)\n      Pbt.integer(min: 1, max: state[:source_balance])\n    end")
        expect(code).to include("current_value = state[:source_balance]")
        expect(code).to include("state.merge(source_balance: state[:source_balance] - delta, target_balance: state[:target_balance] + delta)")
        expect(code).to include("Derived from predicate guards: decide whether guard failures should reject the command or leave state unchanged")
        expect(code).to include('raise "Expected decremented value for Accounts#source_balance" unless after_source_balance == before_source_balance - delta')
        expect(code).to include('raise "Expected incremented value for Accounts#target_balance" unless after_target_balance == before_target_balance + delta')
        expect(code).to include('raise "Expected total scalar value to stay the same" unless after_source_balance + after_target_balance == before_source_balance + before_target_balance')
      end
    end

    context "with connection-pool paired counter transitions" do
      let(:fixture_path) { File.expand_path("../fixtures/alloy/connection_pool.als", __dir__) }
      let(:source) { File.read(fixture_path) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "keeps next_state override hooks valid for no-arg multi-field updates" do
        code = generator.generate

        expect(code).to include("class CheckoutCommand")
        expect(code).to include("def next_state(state, args)\n      override = ConnectionPoolPbtSupport.next_state_override(name)\n      return ConnectionPoolPbtSupport.call_next_state_override(override, state, args) if override\n      return state if ConnectionPoolPbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)\n      state.merge(available: state[:available] - 1, checked_out: state[:checked_out] + 1)")
        expect(code).to include("class CheckinCommand")
        expect(code).to include("def next_state(state, args)\n      override = ConnectionPoolPbtSupport.next_state_override(name)\n      return ConnectionPoolPbtSupport.call_next_state_override(override, state, args) if override\n      return state if ConnectionPoolPbtSupport.guard_failure_policy(name) && !guard_satisfied?(state, args)\n      state.merge(available: state[:available] + 1, checked_out: state[:checked_out] - 1)")
      end
    end

    context "with ledger projection transitions" do
      let(:fixture_path) { File.expand_path("../fixtures/alloy/ledger_projection.als", __dir__) }
      let(:source) { File.read(fixture_path) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "generates append-only collection state plus projected balance updates without requiring next_state overrides" do
        code = generator.generate
        config = generator.generate_config

        expect(code).to include("default_state = { entries: [], balance: 0 } # TODO: replace with a domain-specific structured model state")
        expect(code).to include("state.merge(entries: state[:entries] + [delta], balance: state[:balance] + delta)")
        expect(code).to include("state.merge(entries: state[:entries] + [-delta], balance: state[:balance] - delta)")
        expect(code).to include('raise "Expected appended projection entry to match the model delta" unless after_items.last == delta')
        expect(code).to include('raise "Expected appended projection entry to match the model delta" unless after_items.last == -delta')
        expect(code).to include('raise "Expected incremented value for Ledger#balance" unless after_balance == before_balance + delta')
        expect(code).to include('raise "Expected decremented value for Ledger#balance" unless after_balance == before_balance - delta')
        expect(config).to include("# initial_state: { entries: [], balance: 0 }")
        expect(config).to include("state_reader: nil, # suggested: ->(sut) { { entries: sut.entries.dup, balance: sut.balance } }")
        expect(config).to include('observed_state == after_state')
      end
    end

    context "with feature-flag rollout transitions" do
      let(:fixture_path) { File.expand_path("../fixtures/alloy/feature_flag_rollout.als", __dir__) }
      let(:source) { File.read(fixture_path) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "generates constant and bounded replacement transitions without requiring next_state overrides for disable" do
        code = generator.generate
        config = generator.generate_config

        expect(code).to include("default_state = { rollout: 0, max_rollout: 3 } # TODO: replace with a domain-specific structured model state")
        expect(code).to include("state.merge(rollout: state[:max_rollout])")
        expect(code).to include("state.merge(rollout: 0)")
        expect(code).to include('raise "Expected replaced value for Flag#rollout" unless after_state[:rollout] == expected')
        expect(code).to include("expected = 0")
        expect(code).to include("state.merge(rollout: FeatureFlagRolloutPbtSupport.scalar_model_arg(name, args))")
        expect(config).to include("# initial_state: { rollout: 0, max_rollout: 3 }")
        expect(config).not_to include("next_state_override: ->(state, _args) { state.merge(rollout: 0) }")
      end
    end

    context "with transition-like predicates whose names are not strong verbs" do
      let(:source) do
        <<~ALLOY
          module ledger

          sig Ledger {
            entries: seq Int
          }

          pred Advance[l, l': Ledger, e: Int] {
            #l'.entries = add[#l.entries, 1]
          }

          pred Stable[l, l': Ledger] {
            #l'.entries = #l.entries
          }
        ALLOY
      end
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "treats transition-like predicates as commands even without classic verb prefixes" do
        code = generator.generate

        expect(code).to include("class AdvanceCommand")
        expect(code).to include("class StableCommand")
        expect(code).to include("command_confidence=:medium")
        expect(code).to include("TODO: confirm this predicate should be modeled as a command")
      end
    end

    context "with low-confidence transition evidence" do
      let(:source) do
        <<~ALLOY
          module weak

          sig Box {
            value: one Int
          }

          pred MaybeChange[b, b': Box] {
            b' = b
          }
        ALLOY
      end
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "falls back instead of treating the predicate as a command" do
        code = generator.generate

        expect(code).to include("GeneratedCommand.new")
        expect(code).not_to include("class MaybeChangeCommand")
      end
    end

    context "with prioritized verify hints" do
      let(:fixture_path) { File.expand_path("../fixtures/alloy/stack.als", __dir__) }
      let(:source) { File.read(fixture_path) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "marks assertion/fact/property guidance with a suggested order" do
        code = generator.generate

        expect(code).to include("Suggested verify order:")
        expect(code).to include("1. Command-specific postconditions")
        expect(code).to include("2. Related Alloy assertions/facts")
        expect(code).to include("3. Related property predicates")
        expect(code).to include('raise "Expected non-empty state before removal" if before_items.empty?')
      end
    end
  end

  describe "#generate_config" do
    context "with stack spec" do
      let(:fixture_path) { File.expand_path("../fixtures/alloy/stack.als", __dir__) }
      let(:source) { File.read(fixture_path) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }
      let(:generator) { described_class.new(spec) }

      it "generates a companion Ruby config file for SUT mapping" do
        code = generator.generate_config

        expect(code).to include("StackPbtConfig = {")
        expect(code).to include("sut_factory: -> { StackImpl.new }")
        expect(code).to include("# initial_state: []")
        expect(code).to include("push_adds_element: {")
        expect(code).to include("method: :push_adds_element")
        expect(code).to include("Suggested real API methods: :push")
        expect(code).to include("model_arg_adapter:")
        expect(code).to include("verify_override:")
        expect(code).to include("applicable_override:")
        expect(code).to include("next_state_override:")
        expect(code).to include("observed_state:")
        expect(code).to include("state_reader: nil, # suggested: ->(sut) { sut.snapshot }")
        expect(code).to include('observed_state == after_state')
      end
    end

    context "with bounded queue spec" do
      let(:fixture_path) { File.expand_path("../fixtures/alloy/bounded_queue.als", __dir__) }
      let(:source) { File.read(fixture_path) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }
      let(:generator) { described_class.new(spec) }

      it "suggests collection-oriented readers and verify overrides" do
        code = generator.generate_config

        expect(code).to include("state_reader: nil, # suggested: ->(sut) { sut.snapshot }")
        expect(code).to include('observed_state == after_state[:elements]')
      end
    end

    context "with bank account spec" do
      let(:fixture_path) { File.expand_path("../fixtures/alloy/bank_account.als", __dir__) }
      let(:source) { File.read(fixture_path) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }
      let(:generator) { described_class.new(spec) }

      it "suggests scalar readers and financial API method names" do
        code = generator.generate_config

        expect(code).to include("state_reader: nil, # suggested: ->(sut) { sut.balance }")
        expect(code).to include("# initial_state: 0")
        expect(code).to include("Suggested real API methods: :credit, :deposit")
        expect(code).to include("Suggested real API methods: :debit, :withdraw")
        expect(code).to include("model_arg_adapter: ->(args) { args.abs + 1 }")
        expect(code).to include('Expected observed balance to match model')
      end
    end

    context "with structured scalar wallet state" do
      let(:fixture_path) { File.expand_path("../fixtures/alloy/wallet_with_limit.als", __dir__) }
      let(:source) { File.read(fixture_path) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }
      let(:generator) { described_class.new(spec) }

      it "suggests a structured scalar state_reader" do
        code = generator.generate_config

        expect(code).to include("state_reader: nil, # suggested: ->(sut) { { balance: sut.balance, credit_limit: sut.credit_limit } }")
        expect(code).to include("# initial_state: { balance: 0, credit_limit: 3 }")
        expect(code).to include('observed_state == after_state')
      end
    end

    context "with hold/capture/release state" do
      let(:fixture_path) { File.expand_path("../fixtures/alloy/hold_capture_release.als", __dir__) }
      let(:source) { File.read(fixture_path) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }
      let(:generator) { described_class.new(spec) }

      it "suggests a structured state_reader for multi-field reservation state" do
        code = generator.generate_config

        expect(code).to include("state_reader: nil, # suggested: ->(sut) { { available: sut.available, held: sut.held } }")
        expect(code).to include("# initial_state: { available: 0, held: 0 }")
        expect(code).to include("Suggested real API methods: :authorize, :reserve, :place_hold")
        expect(code).to include("Suggested real API methods: :settle")
        expect(code).to include("Suggested real API methods: :release_hold, :void_authorization")
        expect(code).to include("# guard_failure_policy: :no_op, # or :raise / :custom")
        expect(code).to include("use :no_op for unchanged-state invalid calls, :raise for captured exceptions, or :custom with verify_override")
        expect(code).to include('Expected observed reservation state to match model')
      end
    end

    context "with transfer-between-accounts state" do
      let(:fixture_path) { File.expand_path("../fixtures/alloy/transfer_between_accounts.als", __dir__) }
      let(:source) { File.read(fixture_path) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }
      let(:generator) { described_class.new(spec) }

      it "suggests a structured state_reader for paired balances" do
        code = generator.generate_config

        expect(code).to include("state_reader: nil, # suggested: ->(sut) { { source_balance: sut.source_balance, target_balance: sut.target_balance } }")
        expect(code).to include("# initial_state: { source_balance: 0, target_balance: 0 }")
        expect(code).to include("Suggested real API methods: :move_funds, :transfer_amount, :post_transfer")
        expect(code).to include("# guard_failure_policy: :no_op, # or :raise / :custom")
        expect(code).to include("use :no_op for unchanged-state invalid calls, :raise for captured exceptions, or :custom with verify_override")
        expect(code).to include('Expected observed account balances to match model')
      end
    end
  end
end
