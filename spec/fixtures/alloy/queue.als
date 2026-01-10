-- Alloy specification for a Queue data structure (FIFO)
module queue

sig Element {}

sig Queue {
  elements: seq Element
}

-- Enqueue adds element to back
pred Enqueue[q, q': Queue, e: Element] {
  #q'.elements = add[#q.elements, 1]
}

-- Dequeue removes element from front
pred Dequeue[q, q': Queue] {
  #q.elements > 0 implies #q'.elements = sub[#q.elements, 1]
}

-- Enqueue then Dequeue returns original queue size
pred EnqueueDequeueIdentity[q, q': Queue, e: Element] {
  #q'.elements = #q.elements
}

-- Empty queue has no elements
pred IsEmpty[q: Queue] {
  #q.elements = 0
}

-- FIFO: First In First Out
pred FIFO[q: Queue, enqueued, dequeued: Element] {
  enqueued = dequeued
}

assert QueueProperties {
  all q, q': Queue, e: Element |
    Enqueue[q, q', e] and
    (not IsEmpty[q] implies Dequeue[q, q'])
}

run Enqueue for 3
check QueueProperties for 5
