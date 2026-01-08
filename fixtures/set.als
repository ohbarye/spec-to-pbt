-- Alloy specification for a Set data structure
module set

sig Element {}

sig Set {
  elements: set Element
}

-- Add element to set
pred Add[s, s': Set, e: Element] {
  s'.elements = s.elements + e
}

-- Remove element from set
pred Remove[s, s': Set, e: Element] {
  s'.elements = s.elements - e
}

-- Check if element is in set
pred Contains[s: Set, e: Element] {
  e in s.elements
}

-- Add implies Contains (membership)
pred AddContains[s, s': Set, e: Element] {
  Add[s, s', e] implies Contains[s', e]
}

-- Empty set has no elements
pred IsEmpty[s: Set] {
  #s.elements = 0
}

-- Union is commutative
pred UnionCommutative[a, b: Set] {
  a.elements + b.elements = b.elements + a.elements
}

-- Union is associative
pred UnionAssociative[a, b, c: Set] {
  (a.elements + b.elements) + c.elements = a.elements + (b.elements + c.elements)
}

-- Intersection is commutative
pred IntersectionCommutative[a, b: Set] {
  a.elements & b.elements = b.elements & a.elements
}

assert SetProperties {
  all s, s': Set, e: Element |
    Add[s, s', e] implies Contains[s', e]
}

run Add for 3
check SetProperties for 5
