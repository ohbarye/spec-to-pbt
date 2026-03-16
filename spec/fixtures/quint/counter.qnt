module counter {
  var x: int

  action Inc = all {
    x' = x + 1,
  }

  val NonNegative = x >= 0
}
