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
      end

      it "generates more concrete preconditions and postconditions for common commands" do
        code = generator.generate

        expect(code).to include("!state.empty? # inferred precondition for pop_removes_element")
        expect(code).to include("Expected size to increase by 1")
        expect(code).to include("Expected popped value to match model")
        expect(code).to include("Inferred collection target: Stack#elements")
        expect(code).to include("sut.public_send(:push_adds_element, args)")
      end

      it "adds assertion/fact hints to verify! comments" do
        code = generator.generate

        expect(code).to include("# Related Alloy assertions: StackProperties")
        expect(code).to include("# Assertion/fact pattern hints: empty")
      end

      it "adds sibling property predicate hints for the same state domain" do
        code = generator.generate

        expect(code).to include("# Related Alloy property predicates: PushPopIdentity, IsEmpty, LIFO")
        expect(code).to include("# Related property predicate pattern hints:")
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
        expect(code).to include("# Related Alloy property predicates: EnqueueDequeueIdentity, IsEmpty, FIFO")
        expect(code).to include("# Related property predicate pattern hints:")
        expect(code).to include("empty")
        expect(code).to include("ordering")
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
        expect(code).to include("nil # TODO: replace with a domain-specific scalar/model state")
        expect(code).not_to include("Pbt.tuple(Pbt.integer, Pbt.integer, Pbt.integer)")
        expect(code).to include("state # TODO: update Machine#value based on args/result")
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
        expect(code).to include('state_field="entries"')
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
        expect(code).to include("TODO: update Machine#value based on args/result")
        expect(code).to include("scalar_update_kind=:increment_like")
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

        expect(code).to include('scalar_update_kind=:replace_like')
        expect(code).to include("TODO: replace Thermostat#target using args/result")
        expect(code).to include("TODO: verify replaced value for Thermostat#target")
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

        expect(code).to include('scalar_update_kind=:decrement_like')
        expect(code).to include("TODO: decrease Counter#value based on args/result")
        expect(code).to include("TODO: verify decremented value for Counter#value")
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
      end
    end
  end
end
