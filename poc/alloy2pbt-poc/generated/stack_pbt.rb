# frozen_string_literal: true

# Auto-generated Property-Based Tests from Alloy Specification
# Module: stack
#
# Detected Property Patterns:
#   PushAddsElement: [size]
#   PopRemovesElement: [size]
#   PushPopIdentity: [roundtrip, size]
#   IsEmpty: [empty]
#   LIFO: [roundtrip, ordering]

require "pbt"

# =================================================
# Implementation placeholder - replace with your code
# =================================================

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

# =================================================
# Property-Based Tests
# =================================================

describe "Stack Properties" do
  # Test: Push increases size
  Pbt.assert do
    Pbt.property(Pbt.array(Pbt.integer), Pbt.integer) do |initial, element|
      stack = Stack.new
      initial.each { |e| stack.push(e) }
      
      original_length = stack.length
      stack.push(element)
      
      unless stack.length == original_length + 1
        raise "PushAddsElement failed"
      end
    end
  end

  # Test: Pop decreases size (when not empty)
  Pbt.assert do
    Pbt.property(Pbt.array(Pbt.integer, min: 1)) do |initial|
      stack = Stack.new
      initial.each { |e| stack.push(e) }
      
      original_length = stack.length
      stack.pop
      
      unless stack.length == original_length - 1
        raise "PopRemovesElement failed"
      end
    end
  end

  # Test: LIFO - Last In First Out
  Pbt.assert do
    Pbt.property(Pbt.array(Pbt.integer), Pbt.integer) do |initial, element|
      stack = Stack.new
      initial.each { |e| stack.push(e) }
      
      stack.push(element)
      popped = stack.pop
      
      unless popped == element
        raise "LIFO failed: pushed #{element}, popped #{popped}"
      end
    end
  end

  # Test: Push-Pop identity (round trip)
  Pbt.assert do
    Pbt.property(Pbt.array(Pbt.integer), Pbt.integer) do |initial, element|
      stack = Stack.new
      initial.each { |e| stack.push(e) }
      original_length = stack.length
      
      stack.push(element)
      stack.pop
      
      unless stack.length == original_length
        raise "PushPopIdentity failed"
      end
    end
  end
end