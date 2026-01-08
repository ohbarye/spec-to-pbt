# frozen_string_literal: true

require "spec_helper"

RSpec.describe AlloyToPbt::Parser do
  let(:parser) { described_class.new }

  describe "#parse" do
    context "with sort.als" do
      let(:source) { File.read(File.expand_path("../../fixtures/sort.als", __dir__)) }

      before { parser.parse(source) }

      it "parses the module name" do
        expect(parser.spec.module_name).to eq("sort")
      end

      it "parses signatures" do
        expect(parser.spec.signatures.length).to eq(2)
        expect(parser.spec.signatures.map(&:name)).to contain_exactly("Element", "List")
      end

      it "parses signature fields" do
        element_sig = parser.spec.signatures.find { |s| s.name == "Element" }
        expect(element_sig.fields.length).to eq(1)
        expect(element_sig.fields.first.name).to eq("value")
        expect(element_sig.fields.first.type).to eq("Int")
      end

      it "parses predicates" do
        expect(parser.spec.predicates.length).to eq(4)
        expect(parser.spec.predicates.map(&:name)).to contain_exactly(
          "Sorted", "LengthPreserved", "SameElements", "Idempotent"
        )
      end

      it "parses predicate parameters" do
        sorted_pred = parser.spec.predicates.find { |p| p.name == "Sorted" }
        expect(sorted_pred.params).to eq([{ name: "l", type: "List" }])
      end

      it "parses assertions" do
        expect(parser.spec.assertions.length).to eq(1)
        expect(parser.spec.assertions.first.name).to eq("ValidSort")
      end
    end

    context "with stack.als" do
      let(:source) { File.read(File.expand_path("../../fixtures/stack.als", __dir__)) }

      before { parser.parse(source) }

      it "parses the module name" do
        expect(parser.spec.module_name).to eq("stack")
      end

      it "parses signatures" do
        expect(parser.spec.signatures.length).to eq(2)
        expect(parser.spec.signatures.map(&:name)).to contain_exactly("Element", "Stack")
      end

      it "parses predicates" do
        expect(parser.spec.predicates.length).to eq(5)
        expect(parser.spec.predicates.map(&:name)).to contain_exactly(
          "PushAddsElement", "PopRemovesElement", "PushPopIdentity", "IsEmpty", "LIFO"
        )
      end
    end

    context "with queue.als" do
      let(:source) { File.read(File.expand_path("../../fixtures/queue.als", __dir__)) }

      before { parser.parse(source) }

      it "parses the module name" do
        expect(parser.spec.module_name).to eq("queue")
      end

      it "parses signatures" do
        expect(parser.spec.signatures.length).to eq(2)
        expect(parser.spec.signatures.map(&:name)).to contain_exactly("Element", "Queue")
      end

      it "parses predicates" do
        expect(parser.spec.predicates.length).to eq(5)
        expect(parser.spec.predicates.map(&:name)).to contain_exactly(
          "Enqueue", "Dequeue", "EnqueueDequeueIdentity", "IsEmpty", "FIFO"
        )
      end
    end

    context "with set.als" do
      let(:source) { File.read(File.expand_path("../../fixtures/set.als", __dir__)) }

      before { parser.parse(source) }

      it "parses the module name" do
        expect(parser.spec.module_name).to eq("set")
      end

      it "parses signatures" do
        expect(parser.spec.signatures.length).to eq(2)
        expect(parser.spec.signatures.map(&:name)).to contain_exactly("Element", "Set")
      end

      it "parses predicates" do
        expect(parser.spec.predicates.length).to eq(8)
        expect(parser.spec.predicates.map(&:name)).to include(
          "Add", "Remove", "Contains", "UnionCommutative", "UnionAssociative"
        )
      end

      it "parses set field multiplicity" do
        set_sig = parser.spec.signatures.find { |s| s.name == "Set" }
        expect(set_sig.fields.first.multiplicity).to eq("set")
      end
    end

    context "with comments" do
      let(:source) do
        <<~ALLOY
          -- This is a line comment
          module test
          // Another comment
          /* Block
             comment */
          sig Foo {}
        ALLOY
      end

      before { parser.parse(source) }

      it "removes comments and parses correctly" do
        expect(parser.spec.module_name).to eq("test")
        expect(parser.spec.signatures.length).to eq(1)
        expect(parser.spec.signatures.first.name).to eq("Foo")
      end
    end
  end

  describe "#to_h" do
    let(:source) { "module test\nsig Foo { bar: one Int }" }

    before { parser.parse(source) }

    it "returns a hash representation" do
      hash = parser.to_h
      expect(hash[:module]).to eq("test")
      expect(hash[:signatures].first[:name]).to eq("Foo")
      expect(hash[:signatures].first[:fields].first[:name]).to eq("bar")
    end
  end

  describe "#to_json" do
    let(:source) { "module test\nsig Foo {}" }

    before { parser.parse(source) }

    it "returns valid JSON" do
      json = parser.to_json
      parsed = JSON.parse(json)
      expect(parsed["module"]).to eq("test")
    end
  end
end
