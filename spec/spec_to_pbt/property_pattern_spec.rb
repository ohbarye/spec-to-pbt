# frozen_string_literal: true

require "spec_helper"

RSpec.describe SpecToPbt::PropertyPattern do
  describe ".detect" do
    it "detects roundtrip patterns" do
      patterns = described_class.detect("PushPopIdentity", "push then pop")
      expect(patterns).to include(:roundtrip)
    end

    it "detects idempotent patterns" do
      patterns = described_class.detect("Idempotent", "sort[sort[x]] = sort[x]")
      expect(patterns).to include(:idempotent)
    end

    it "detects invariant patterns" do
      patterns = described_class.detect("Sorted", "all elements are sorted")
      expect(patterns).to include(:invariant)
    end

    it "detects size patterns" do
      patterns = described_class.detect("LengthPreserved", "#input = #output")
      expect(patterns).to include(:size)
    end

    it "detects elements patterns" do
      patterns = described_class.detect("SameElements", "same elements permutation")
      expect(patterns).to include(:elements)
    end

    it "detects empty patterns" do
      patterns = described_class.detect("IsEmpty", "#elements = 0")
      expect(patterns).to include(:empty)
    end

    it "detects ordering patterns" do
      patterns = described_class.detect("LIFO", "last in first out")
      expect(patterns).to include(:ordering)
    end

    it "returns empty array when no patterns match" do
      patterns = described_class.detect("Unknown", "no recognizable pattern")
      expect(patterns).to be_empty
    end

    it "detects multiple patterns" do
      patterns = described_class.detect("SortPreserved", "sorted and #input = #output")
      expect(patterns).to include(:invariant, :size)
    end

    it "detects associativity patterns" do
      patterns = described_class.detect("UnionAssociative", "(a + b) + c = a + (b + c)")
      expect(patterns).to include(:associativity)
    end

    it "detects commutativity patterns" do
      patterns = described_class.detect("UnionCommutative", "a + b = b + a")
      expect(patterns).to include(:commutativity)
    end

    it "detects membership patterns" do
      patterns = described_class.detect("AddContains", "add implies contains")
      expect(patterns).to include(:membership)
    end

    it "detects membership with in keyword" do
      patterns = described_class.detect("Contains", "e in s.elements")
      expect(patterns).to include(:membership)
    end
  end
end
