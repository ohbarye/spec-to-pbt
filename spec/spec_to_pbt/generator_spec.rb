# frozen_string_literal: true

require "spec_helper"

RSpec.describe SpecToPbt::Generator do
  describe "#generate" do
    context "with sort spec (idempotent + invariant + size patterns)" do
      let(:spec) do
        SpecToPbt::Spec.new(
          module_name: "sort",
          signatures: [
            SpecToPbt::Signature.new(name: "List", fields: [
              SpecToPbt::Field.new(name: "elements", type: "Int", multiplicity: "seq")
            ])
          ],
          predicates: [
            SpecToPbt::Predicate.new(
              name: "Sorted",
              params: [{ name: "l", type: "List" }],
              body: "all i: sorted"
            ),
            SpecToPbt::Predicate.new(
              name: "Idempotent",
              params: [{ name: "l", type: "List" }],
              body: "sort(sort(l)) = sort(l)"
            )
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

      it "includes require_relative for impl" do
        code = generator.generate
        expect(code).to include('require_relative "sort_impl"')
      end

      it "includes RSpec describe block" do
        code = generator.generate
        expect(code).to include('RSpec.describe "sort"')
      end

      it "includes Pbt.assert" do
        code = generator.generate
        expect(code).to include("Pbt.assert")
      end

      it "generates check code for invariant pattern" do
        code = generator.generate
        expect(code).to include("Invariant failed")
      end

      it "generates check code for idempotent pattern" do
        code = generator.generate
        expect(code).to include("Idempotent failed")
      end
    end

    context "with stack spec (size + roundtrip patterns)" do
      let(:spec) do
        SpecToPbt::Spec.new(
          module_name: "stack",
          signatures: [
            SpecToPbt::Signature.new(name: "Stack", fields: [
              SpecToPbt::Field.new(name: "elements", type: "Int", multiplicity: "seq")
            ])
          ],
          predicates: [
            SpecToPbt::Predicate.new(
              name: "PushAddsElement",
              params: [{ name: "s", type: "Stack" }],
              body: "#stack' = add[#stack, 1]"
            ),
            SpecToPbt::Predicate.new(
              name: "PushPopIdentity",
              params: [{ name: "s", type: "Stack" }],
              body: "push then pop returns original"
            )
          ]
        )
      end
      let(:generator) { described_class.new(spec) }

      it "generates valid Ruby code" do
        code = generator.generate
        expect { RubyVM::InstructionSequence.compile(code) }.not_to raise_error
      end

      it "generates check code for size pattern" do
        code = generator.generate
        expect(code).to include("Size failed")
      end

      it "generates check code for roundtrip pattern" do
        code = generator.generate
        expect(code).to include("Roundtrip failed")
      end
    end

    context "with unsupported patterns" do
      let(:spec) do
        SpecToPbt::Spec.new(
          module_name: "custom",
          predicates: [
            SpecToPbt::Predicate.new(
              name: "SameElements",
              body: "elems = elems (elements pattern)"
            )
          ]
        )
      end
      let(:generator) { described_class.new(spec) }

      it "generates valid Ruby code" do
        code = generator.generate
        expect { RubyVM::InstructionSequence.compile(code) }.not_to raise_error
      end

      it "includes unsupported pattern in comments" do
        code = generator.generate
        expect(code).to include("Unsupported patterns detected: elements")
      end

      it "skips the test for unsupported patterns" do
        code = generator.generate
        expect(code).to include("No supported patterns detected")
      end
    end

    context "with no patterns detected" do
      let(:spec) do
        SpecToPbt::Spec.new(
          module_name: "empty",
          predicates: [
            SpecToPbt::Predicate.new(name: "Unknown", body: "xyz abc")
          ]
        )
      end
      let(:generator) { described_class.new(spec) }

      it "generates valid Ruby code" do
        code = generator.generate
        expect { RubyVM::InstructionSequence.compile(code) }.not_to raise_error
      end

      it "indicates pending implementation" do
        code = generator.generate
        expect(code).to include("is pending implementation")
      end
    end
  end

  describe "#analyze" do
    let(:spec) do
      SpecToPbt::Spec.new(
        module_name: "test",
        predicates: [
          SpecToPbt::Predicate.new(name: "Sorted", body: "ordered elements"),
          SpecToPbt::Predicate.new(name: "LIFO", body: "last in first out")
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
