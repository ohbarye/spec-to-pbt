# frozen_string_literal: true

# Auto-generated Property-Based Tests from Alloy Specification
# Module: sort
#
# Detected Property Patterns:
#   Sorted: [invariant, size]
#   LengthPreserved: [invariant, size]
#   SameElements: [elements]
#   Idempotent: [idempotent, invariant]

require "pbt"

# =================================================
# Implementation placeholder - replace with your code
# =================================================

def sort(array)
  # TODO: Replace with your implementation
  array.sort
end

# =================================================
# Property-Based Tests
# =================================================

describe "Sort Properties" do
  Pbt.assert do
    Pbt.property(Pbt.array(Pbt.integer)) do |input|
      output = sort(input)

      # Property 1: Sorted - output is in ascending order
      unless output.each_cons(2).all? { |a, b| a <= b }
        raise "Sorted property failed: #{output.inspect}"
      end

      # Property 2: LengthPreserved - same number of elements
      unless input.length == output.length
        raise "LengthPreserved failed: #{input.length} != #{output.length}"
      end

      # Property 3: SameElements - output is a permutation of input
      unless input.sort == output.sort
        raise "SameElements failed: elements differ"
      end

      # Property 4: Idempotent - sorting a sorted array gives same result
      unless sort(output) == output
        raise "Idempotent failed: sort(sort(x)) != sort(x)"
      end
    end
  end
end