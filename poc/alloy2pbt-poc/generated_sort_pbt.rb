# frozen_string_literal: true

# Auto-generated from Alloy specification
# Module: sort

require "pbt"

# === Alloy Specification Summary ===
#
# Signature: Element
#   - value: one Int
# Signature: List
#   - elements: seq Element
#
# Predicate: Sorted[l]
# Predicate: LengthPreserved[input, output]
# Predicate: SameElements[input, output]
# Predicate: Idempotent[l]
# Assertion: ValidSort

# === Arbitrary Definitions ===

# Arbitrary for input: Array of Integers
INPUT_ARBITRARY = Pbt.array(Pbt.integer)


# === Property Tests ===

Pbt.assert do
  Pbt.property(INPUT_ARBITRARY) do |input|
    # Apply the function under test
    output = sort(input)  # Replace with your implementation

    # Property: Sorted
    raise "Sorted failed" unless output.each_cons(2).all? { |a, b| a <= b }

    # Property: LengthPreserved
    raise "LengthPreserved failed" unless input.length == output.length

    # Property: SameElements
    raise "SameElements failed" unless input.sort == output.sort

    # Property: Idempotent
    raise "Idempotent failed" unless sort(output) == output

  end
end
