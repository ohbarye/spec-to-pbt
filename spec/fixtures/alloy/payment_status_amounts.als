module payment_status_amounts

sig Payment {
  status: one Int,
  authorized_amount: one Int,
  captured_amount: one Int
}

pred AuthorizeAmount[p, p': Payment, amount: Int] {
  #p.status = 0 implies #p'.status = 1 and #p'.authorized_amount = add[#p.authorized_amount, amount] and #p'.captured_amount = #p.captured_amount
}

pred CaptureAmount[p, p': Payment, amount: Int] {
  #p.authorized_amount >= amount implies #p'.status = 2 and #p'.authorized_amount = sub[#p.authorized_amount, amount] and #p'.captured_amount = add[#p.captured_amount, amount]
}

pred Reset[p, p': Payment] {
  #p.status = 2 implies #p'.status = 0 and #p'.authorized_amount = 0 and #p'.captured_amount = 0
}

pred NonNegativeAuthorized[p: Payment] {
  #p.authorized_amount >= 0
}

pred NonNegativeCaptured[p: Payment] {
  #p.captured_amount >= 0
}
