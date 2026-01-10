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
      it "generates check code using operation from context" do
        code = described_class.generate(:idempotent, operation: "sort")
        expect(code).to include("sort(input)")
        expect(code).to include("sort(result)")
        expect(code).to include('raise "Idempotent failed"')
      end

      it "generates check code with custom operation" do
        code = described_class.generate(:idempotent, operation: "my_func")
        expect(code).to include("my_func(input)")
        expect(code).to include("my_func(result)")
      end
    end

    context "with size pattern" do
      it "generates check code for length preservation" do
        code = described_class.generate(:size, operation: "transform")
        expect(code).to include("transform(input)")
        expect(code).to include("input.length == output.length")
        expect(code).to include('raise "Size failed"')
      end
    end

    context "with roundtrip pattern" do
      it "generates check code using operation from context" do
        code = described_class.generate(:roundtrip, operation: "reverse")
        expect(code).to include("reverse(input)")
        expect(code).to include("reverse(result)")
        expect(code).to include('raise "Roundtrip failed"')
        expect(code).to include("restored == input")
      end

      it "generates check code for self-inverse function" do
        code = described_class.generate(:roundtrip, operation: "swap")
        expect(code).to include("swap(input)")
        expect(code).to include("swap(result)")
      end
    end

    context "with invariant pattern" do
      it "generates check code calling invariant? helper" do
        code = described_class.generate(:invariant, operation: "sort")
        expect(code).to include("sort(input)")
        expect(code).to include("invariant?(output)")
        expect(code).to include('raise "Invariant failed"')
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
