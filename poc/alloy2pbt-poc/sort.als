-- Alloy specification for a sorting function
module sort

sig Element {
  value: one Int
}

sig List {
  elements: seq Element
}

-- The output list should be sorted
pred Sorted[l: List] {
  all i: Int | (i >= 0 and i < sub[#l.elements, 1]) implies
    l.elements[i].value <= l.elements[add[i, 1]].value
}

-- Length is preserved after sorting
pred LengthPreserved[input, output: List] {
  #input.elements = #output.elements
}

-- All elements are preserved (permutation)
pred SameElements[input, output: List] {
  input.elements.elems = output.elements.elems
}

-- Idempotent: sorting a sorted list gives the same list
pred Idempotent[l: List] {
  Sorted[l] implies l.elements = l.elements
}

-- Main assertion: a valid sort operation
assert ValidSort {
  all input, output: List |
    (LengthPreserved[input, output] and 
     SameElements[input, output] and 
     Sorted[output])
}

run Sorted for 5
check ValidSort for 5
