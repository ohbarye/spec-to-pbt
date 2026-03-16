module list_counter {
  var items: List[int]

  action Enqueue(x) = all {
    items' = append(items, x),
  }

  action Dequeue = all {
    length(items) > 0,
    items' = tail(items),
  }

  val NonEmpty = length(items) >= 0
}
