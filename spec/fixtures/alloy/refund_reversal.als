module refund_reversal

sig Settlement {
  captured: one Int,
  refunded: one Int
}

pred Capture[s, s': Settlement, amount: Int] {
  #s'.captured = add[#s.captured, amount]
}

pred Refund[s, s': Settlement, amount: Int] {
  #s.captured >= amount implies #s'.captured = sub[#s.captured, amount] and #s'.refunded = add[#s.refunded, amount]
}

pred Reverse[s, s': Settlement, amount: Int] {
  #s.refunded >= amount implies #s'.captured = add[#s.captured, amount] and #s'.refunded = sub[#s.refunded, amount]
}

pred NonNegativeCaptured[s: Settlement] {
  #s.captured >= 0
}

pred NonNegativeRefunded[s: Settlement] {
  #s.refunded >= 0
}
