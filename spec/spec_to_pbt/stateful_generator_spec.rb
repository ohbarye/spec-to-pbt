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
        expect(code).to include("sut.public_send(:push_adds_element, args)")
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
  end
end
