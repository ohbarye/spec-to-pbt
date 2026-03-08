module membership_queue

sig Element {}

sig Queue {
  elements: seq Element
}

pred Enqueue[q, q': Queue, e: Element] {
  #q'.elements = add[#q.elements, 1]
}

pred Dequeue[q, q': Queue] {
  #q.elements > 0 implies #q'.elements = sub[#q.elements, 1]
}

pred EnqueueContains[q, q': Queue, e: Element] {
  Enqueue[q, q', e] implies e in q'.elements
}
