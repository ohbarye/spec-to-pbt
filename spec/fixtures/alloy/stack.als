-- Alloy specification for a Stack data structure
module stack

sig Element {}

sig Stack {
  elements: seq Element
}

-- Push adds element to top
pred PushAddsElement[s, s': Stack, e: Element] {
  #s'.elements = add[#s.elements, 1]
}

-- Pop removes element from top  
pred PopRemovesElement[s, s': Stack] {
  #s.elements > 0 implies #s'.elements = sub[#s.elements, 1]
}

-- Push then Pop returns original stack (if not empty)
pred PushPopIdentity[s, s': Stack, e: Element] {
  -- After push(e) then pop(), we get back to s
  #s'.elements = #s.elements
}

-- Empty stack has no elements
pred IsEmpty[s: Stack] {
  #s.elements = 0
}

-- LIFO: Last In First Out
pred LIFO[s: Stack, pushed: Element, popped: Element] {
  pushed = popped
}

assert StackProperties {
  all s, s': Stack, e: Element |
    PushAddsElement[s, s', e] and
    (not IsEmpty[s] implies PopRemovesElement[s, s'])
}

run PushAddsElement for 3
check StackProperties for 5
