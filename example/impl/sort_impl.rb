# frozen_string_literal: true

# Implementation for sort property tests
# The module name "sort" becomes the operation name

def sort(array)
  array.sort
end

# Helper for invariant pattern - checks if output satisfies the invariant
def invariant?(array)
  array.each_cons(2).all? { |a, b| a <= b }
end
