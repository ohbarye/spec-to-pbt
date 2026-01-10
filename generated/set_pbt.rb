# frozen_string_literal: true

# Auto-generated Property-Based Tests from Alloy Specification
# Module: set

require "pbt"
require "set"

# Implementation stub - uses Ruby's built-in Set
class MySet
  def initialize
    @elements = ::Set.new
  end

  def add(element)
    @elements.add(element)
    self
  end

  def remove(element)
    @elements.delete(element)
    self
  end

  def contains?(element)
    @elements.include?(element)
  end

  def empty?
    @elements.empty?
  end

  def size
    @elements.size
  end

  def union(other)
    result = MySet.new
    @elements.each { |e| result.add(e) }
    other.instance_variable_get(:@elements).each { |e| result.add(e) }
    result
  end

  def intersection(other)
    result = MySet.new
    other_elements = other.instance_variable_get(:@elements)
    @elements.each { |e| result.add(e) if other_elements.include?(e) }
    result
  end

  def ==(other)
    @elements == other.instance_variable_get(:@elements)
  end

  def to_a
    @elements.to_a
  end
end

RSpec.describe "set" do
  describe "Set Properties" do
    it "add then contains" do
      Pbt.assert do
        Pbt.property(Pbt.array(Pbt.integer), Pbt.integer) do |initial, element|
          set = MySet.new
          initial.each { |e| set.add(e) }

          set.add(element)

          raise "AddContains failed" unless set.contains?(element)
        end
      end
    end

    it "remove then not contains" do
      Pbt.assert do
        Pbt.property(Pbt.array(Pbt.integer), Pbt.integer) do |initial, element|
          set = MySet.new
          initial.each { |e| set.add(e) }
          set.add(element)

          set.remove(element)

          raise "RemoveNotContains failed" if set.contains?(element)
        end
      end
    end

    it "union is commutative" do
      Pbt.assert do
        Pbt.property(Pbt.array(Pbt.integer), Pbt.array(Pbt.integer)) do |arr_a, arr_b|
          set_a = MySet.new
          arr_a.each { |e| set_a.add(e) }

          set_b = MySet.new
          arr_b.each { |e| set_b.add(e) }

          raise "UnionCommutative failed" unless set_a.union(set_b) == set_b.union(set_a)
        end
      end
    end

    it "union is associative" do
      Pbt.assert do
        Pbt.property(Pbt.array(Pbt.integer), Pbt.array(Pbt.integer), Pbt.array(Pbt.integer)) do |arr_a, arr_b, arr_c|
          set_a = MySet.new
          arr_a.each { |e| set_a.add(e) }

          set_b = MySet.new
          arr_b.each { |e| set_b.add(e) }

          set_c = MySet.new
          arr_c.each { |e| set_c.add(e) }

          raise "UnionAssociative failed" unless set_a.union(set_b).union(set_c) == set_a.union(set_b.union(set_c))
        end
      end
    end

    it "intersection is commutative" do
      Pbt.assert do
        Pbt.property(Pbt.array(Pbt.integer), Pbt.array(Pbt.integer)) do |arr_a, arr_b|
          set_a = MySet.new
          arr_a.each { |e| set_a.add(e) }

          set_b = MySet.new
          arr_b.each { |e| set_b.add(e) }

          raise "IntersectionCommutative failed" unless set_a.intersection(set_b) == set_b.intersection(set_a)
        end
      end
    end
  end
end
