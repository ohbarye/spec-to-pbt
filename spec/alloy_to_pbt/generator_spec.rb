# frozen_string_literal: true

require "spec_helper"

RSpec.describe AlloyToPbt::Generator do
  describe "#generate" do
    context "with sort spec" do
      let(:spec) do
        AlloyToPbt::Spec.new(
          module_name: "sort",
          predicates: [
            AlloyToPbt::Predicate.new(name: "Sorted", body: "all i: sorted"),
            AlloyToPbt::Predicate.new(name: "LengthPreserved", body: "#input = #output")
          ]
        )
      end
      let(:generator) { described_class.new(spec) }

      it "generates valid Ruby code" do
        code = generator.generate
        expect { RubyVM::InstructionSequence.compile(code) }.not_to raise_error
      end

      it "includes require pbt" do
        code = generator.generate
        expect(code).to include('require "pbt"')
      end

      it "includes RSpec describe block" do
        code = generator.generate
        expect(code).to include('RSpec.describe "sort"')
      end

      it "includes sort implementation stub" do
        code = generator.generate
        expect(code).to include("def sort(array)")
      end

      it "includes Pbt.assert" do
        code = generator.generate
        expect(code).to include("Pbt.assert")
      end

      it "includes property checks" do
        code = generator.generate
        expect(code).to include("Sorted failed")
        expect(code).to include("LengthPreserved failed")
      end
    end

    context "with stack spec" do
      let(:spec) do
        AlloyToPbt::Spec.new(
          module_name: "stack",
          predicates: [
            AlloyToPbt::Predicate.new(name: "PushAddsElement", body: "#stack' = #stack + 1")
          ]
        )
      end
      let(:generator) { described_class.new(spec) }

      it "generates valid Ruby code" do
        code = generator.generate
        expect { RubyVM::InstructionSequence.compile(code) }.not_to raise_error
      end

      it "includes Stack class stub" do
        code = generator.generate
        expect(code).to include("class Stack")
      end

      it "includes stack property tests" do
        code = generator.generate
        expect(code).to include("push increases size")
        expect(code).to include("LIFO")
      end
    end

    context "with generic spec" do
      let(:spec) do
        AlloyToPbt::Spec.new(
          module_name: "custom",
          predicates: [
            AlloyToPbt::Predicate.new(name: "CustomProp", body: "some custom logic")
          ]
        )
      end
      let(:generator) { described_class.new(spec) }

      it "generates valid Ruby code" do
        code = generator.generate
        expect { RubyVM::InstructionSequence.compile(code) }.not_to raise_error
      end

      it "includes predicate name in comments" do
        code = generator.generate
        expect(code).to include("CustomProp")
      end
    end

    context "with queue spec" do
      let(:spec) do
        AlloyToPbt::Spec.new(
          module_name: "queue",
          predicates: [
            AlloyToPbt::Predicate.new(name: "Enqueue", body: "#q'.elements = add[#q.elements, 1]")
          ]
        )
      end
      let(:generator) { described_class.new(spec) }

      it "generates valid Ruby code" do
        code = generator.generate
        expect { RubyVM::InstructionSequence.compile(code) }.not_to raise_error
      end

      it "includes Queue class stub" do
        code = generator.generate
        expect(code).to include("class Queue")
      end

      it "includes queue property tests" do
        code = generator.generate
        expect(code).to include("enqueue increases size")
        expect(code).to include("FIFO")
      end
    end

    context "with set spec" do
      let(:spec) do
        AlloyToPbt::Spec.new(
          module_name: "set",
          predicates: [
            AlloyToPbt::Predicate.new(name: "Add", body: "s'.elements = s.elements + e")
          ]
        )
      end
      let(:generator) { described_class.new(spec) }

      it "generates valid Ruby code" do
        code = generator.generate
        expect { RubyVM::InstructionSequence.compile(code) }.not_to raise_error
      end

      it "includes MySet class stub" do
        code = generator.generate
        expect(code).to include("class MySet")
      end

      it "includes set property tests" do
        code = generator.generate
        expect(code).to include("add then contains")
        expect(code).to include("union is commutative")
        expect(code).to include("union is associative")
      end
    end
  end

  describe "#analyze" do
    let(:spec) do
      AlloyToPbt::Spec.new(
        module_name: "test",
        predicates: [
          AlloyToPbt::Predicate.new(name: "Sorted", body: "ordered elements"),
          AlloyToPbt::Predicate.new(name: "LIFO", body: "last in first out")
        ]
      )
    end
    let(:generator) { described_class.new(spec) }

    it "detects patterns for each predicate" do
      result = generator.analyze
      expect(result["Sorted"][:patterns]).to include(:invariant)
      expect(result["LIFO"][:patterns]).to include(:ordering)
    end
  end
end
