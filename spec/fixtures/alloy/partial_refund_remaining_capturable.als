module partial_refund_remaining_capturable

sig Payment {
  authorized: one Int,
  captured: one Int,
  refunded: one Int
}

pred Capture[p, p': Payment, amount: Int] {
  #p.authorized >= amount implies
    #p'.authorized = sub[#p.authorized, amount] and
    #p'.captured = add[#p.captured, amount]
}

pred Refund[p, p': Payment, amount: Int] {
  #p.captured >= amount implies
    #p'.captured = sub[#p.captured, amount] and
    #p'.refunded = add[#p.refunded, amount]
}

pred NonNegativeAuthorized[p: Payment] {
  #p.authorized >= 0
}

pred NonNegativeCaptured[p: Payment] {
  #p.captured >= 0
}

pred NonNegativeRefunded[p: Payment] {
  #p.refunded >= 0
}
