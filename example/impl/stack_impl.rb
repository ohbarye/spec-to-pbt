# frozen_string_literal: true

# Implementation for stack property tests
class Stack
  def initialize
    @elements = []
  end

  def push(element)
    @elements.push(element)
  end

  def pop
    @elements.pop
  end

  def length
    @elements.length
  end

  def to_a
    @elements.dup
  end
end

def push(stack, element)
  stack.push(element)
end

def pop(stack)
  stack.pop
end
