module cache

sig Cache {
  entries: seq Int
}

pred Rewrite[c, c': Cache] {
  #c'.entries = #c.entries
}
