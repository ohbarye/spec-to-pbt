module weak

sig Box {
  value: one Int
}

pred MaybeChange[b, b': Box] {
  b' = b
}
