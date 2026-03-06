module box

sig Box {
  value: one Int
}

pred Keep[b, b': Box] {
  #b'.value = #b.value
}
