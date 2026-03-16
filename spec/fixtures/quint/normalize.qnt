module normalize {
  pure def normalize(xs: List[int]): List[int] = xs

  val Idempotent = normalize(normalize([1])) == normalize([1])
}
