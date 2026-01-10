# frozen_string_literal: true

require "spec_helper"

RSpec.describe AlloyToPbt::PatternCodeGenerator do
  describe ".supported?" do
    it "returns true for idempotent" do
      expect(described_class.supported?(:idempotent)).to be true
    end

    it "returns true for size" do
      expect(described_class.supported?(:size)).to be true
    end

    it "returns true for roundtrip" do
      expect(described_class.supported?(:roundtrip)).to be true
    end

    it "returns true for invariant" do
      expect(described_class.supported?(:invariant)).to be true
    end

    it "returns false for unsupported patterns" do
      expect(described_class.supported?(:unknown)).to be false
      expect(described_class.supported?(:elements)).to be false
    end
  end

  describe ".generate" do
    context "with idempotent pattern" do
      it "generates check code with default operation (sort)" do
        code = described_class.generate(:idempotent)
        expect(code).to include("sort(input)")
        expect(code).to include("sort(output)")
        expect(code).to include('raise "Idempotent failed"')
      end

      it "generates check code with custom operation" do
        code = described_class.generate(:idempotent, operation: "my_sort")
        expect(code).to include("my_sort(input)")
        expect(code).to include("my_sort(output)")
      end
    end

    context "with size pattern" do
      it "generates check code for length preservation" do
        code = described_class.generate(:size)
        expect(code).to include("input.length == output.length")
        expect(code).to include('raise "Size failed"')
      end
    end

    context "with roundtrip pattern" do
      it "generates check code with default operations" do
        code = described_class.generate(:roundtrip)
        expect(code).to include("push(input, value)")
        expect(code).to include("pop(input)")
        expect(code).to include('raise "Roundtrip failed"')
      end

      it "generates check code with custom operations" do
        code = described_class.generate(:roundtrip, operations: %w[enqueue dequeue])
        expect(code).to include("enqueue(input, value)")
        expect(code).to include("dequeue(input)")
      end
    end

    context "with invariant pattern" do
      it "generates check code with default check" do
        code = described_class.generate(:invariant)
        expect(code).to include("each_cons(2).all?")
        expect(code).to include('raise "Invariant failed"')
      end

      it "generates check code with custom invariant" do
        code = described_class.generate(:invariant, invariant_check: "valid?")
        expect(code).to include("output.valid?")
      end
    end

    context "with unsupported pattern" do
      it "returns nil" do
        expect(described_class.generate(:unknown)).to be_nil
      end
    end
  end

  describe "SUPPORTED_PATTERNS" do
    it "includes exactly 4 patterns" do
      expect(described_class::SUPPORTED_PATTERNS.size).to eq(4)
    end

    it "includes all expected patterns" do
      expect(described_class::SUPPORTED_PATTERNS).to contain_exactly(
        :idempotent, :size, :roundtrip, :invariant
      )
    end
  end
end
