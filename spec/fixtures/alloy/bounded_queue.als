module bounded_queue

sig Element {}

sig Queue {
  elements: seq Element,
  capacity: one Int
}

pred Enqueue[q, q': Queue, e: Element] {
  #q.elements < #q.capacity implies #q'.elements = add[#q.elements, 1]
}

pred Dequeue[q, q': Queue] {
  #q.elements > 0 implies #q'.elements = sub[#q.elements, 1]
}

pred EnqueueDequeueIdentity[q, q': Queue, e: Element] {
  #q'.elements = #q.elements
}

pred IsEmpty[q: Queue] {
  #q.elements = 0
}

pred IsFull[q: Queue] {
  #q.elements = #q.capacity
}

pred FIFO[q: Queue, enqueued, dequeued: Element] {
  enqueued = dequeued
}

assert QueueBounds {
  all q, q': Queue, e: Element |
    (not IsFull[q] implies Enqueue[q, q', e]) and
    (not IsEmpty[q] implies Dequeue[q, q'])
}
