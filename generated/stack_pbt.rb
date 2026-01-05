# frozen_string_literal: true

# Auto-generated Property-Based Tests from Alloy Specification
# Module: stack

require "pbt"

# Implementation stub - replace with your actual implementation
class Stack
  def initialize
    @elements = []
  end

  def push(element)
    @elements.push(element)
    self
  end

  def pop
    @elements.pop
  end

  def peek
    @elements.last
  end

  def empty?
    @elements.empty?
  end

  def length
    @elements.length
  end

  def ==(other)
    @elements == other.instance_variable_get(:@elements)
  end

  def dup
    s = Stack.new
    @elements.each { |e| s.push(e) }
    s
  end
end

RSpec.describe "stack" do
  describe "Stack Properties" do
    it "push increases size by 1" do
      Pbt.assert do
        Pbt.property(Pbt.array(Pbt.integer), Pbt.integer) do |initial, element|
          stack = Stack.new
          initial.each { |e| stack.push(e) }

          original_length = stack.length
          stack.push(element)

          raise "PushAddsElement failed" unless stack.length == original_length + 1
        end
      end
    end

    it "pop decreases size by 1 (when not empty)" do
      Pbt.assert do
        Pbt.property(Pbt.array(Pbt.integer, min: 1)) do |initial|
          stack = Stack.new
          initial.each { |e| stack.push(e) }

          original_length = stack.length
          stack.pop

          raise "PopRemovesElement failed" unless stack.length == original_length - 1
        end
      end
    end

    it "LIFO - Last In First Out" do
      Pbt.assert do
        Pbt.property(Pbt.array(Pbt.integer), Pbt.integer) do |initial, element|
          stack = Stack.new
          initial.each { |e| stack.push(e) }

          stack.push(element)
          popped = stack.pop

          raise "LIFO failed" unless popped == element
        end
      end
    end

    it "push-pop identity (round trip)" do
      Pbt.assert do
        Pbt.property(Pbt.array(Pbt.integer), Pbt.integer) do |initial, element|
          stack = Stack.new
          initial.each { |e| stack.push(e) }
          original_length = stack.length

          stack.push(element)
          stack.pop

          raise "PushPopIdentity failed" unless stack.length == original_length
        end
      end
    end
  end
end
