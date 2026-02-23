# frozen_string_literal: true

require "spec_helper"

RSpec.describe SpecToPbt::TypeInferrer do
  let(:spec) { SpecToPbt::Spec.new(signatures: signatures) }
  let(:inferrer) { described_class.new(spec) }

  describe "#generator_for" do
    context "with basic types" do
      let(:signatures) { [] }

      it "returns Pbt.integer for Int" do
        expect(inferrer.generator_for("Int")).to eq("Pbt.integer")
      end

      it "returns Pbt.string for String" do
        expect(inferrer.generator_for("String")).to eq("Pbt.string")
      end

      it "returns Pbt.integer for unknown types (default)" do
        expect(inferrer.generator_for("Unknown")).to eq("Pbt.integer")
      end
    end

    context "with multiplicity" do
      let(:signatures) { [] }

      it "wraps with Pbt.array for seq multiplicity" do
        expect(inferrer.generator_for("Int", "seq")).to eq("Pbt.array(Pbt.integer)")
      end

      it "wraps with Pbt.array for set multiplicity" do
        expect(inferrer.generator_for("Int", "set")).to eq("Pbt.array(Pbt.integer)")
      end

      it "returns base type for one multiplicity" do
        expect(inferrer.generator_for("Int", "one")).to eq("Pbt.integer")
      end
    end

    context "with custom signatures" do
      let(:signatures) do
        [
          SpecToPbt::Signature.new(
            name: "Element",
            fields: [SpecToPbt::Field.new(name: "value", type: "Int", multiplicity: "one")]
          ),
          SpecToPbt::Signature.new(
            name: "List",
            fields: [SpecToPbt::Field.new(name: "elements", type: "Element", multiplicity: "seq")]
          )
        ]
      end

      it "resolves Element to its field type (Int)" do
        expect(inferrer.generator_for("Element")).to eq("Pbt.integer")
      end

      it "resolves List to array of its field type" do
        expect(inferrer.generator_for("List")).to eq("Pbt.array(Pbt.integer)")
      end
    end

    context "with empty signature fields" do
      let(:signatures) do
        [SpecToPbt::Signature.new(name: "Empty", fields: [])]
      end

      it "returns Pbt.integer for sig with no fields" do
        expect(inferrer.generator_for("Empty")).to eq("Pbt.integer")
      end
    end
  end
end
