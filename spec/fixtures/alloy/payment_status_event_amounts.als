module payment_status_event_amounts

sig Payment {
  status: one Int,
  captures: seq Int,
  remaining_amount: one Int,
  settled_amount: one Int
}

pred Open[p, p': Payment] {
  #p.status = 0 implies #p'.status = 1 and #p'.captures = #p.captures and #p'.remaining_amount = #p.remaining_amount and #p'.settled_amount = #p.settled_amount
}

pred SettleUnit[p, p': Payment] {
  #p.status = 1 and #p.remaining_amount > 0 implies #p'.status = #p.status and #p'.captures = add[#p.captures, 1] and #p'.remaining_amount = sub[#p.remaining_amount, 1] and #p'.settled_amount = add[#p.settled_amount, 1]
}

pred Close[p, p': Payment] {
  #p.status = 1 implies #p'.status = 2 and #p'.captures = #p.captures and #p'.remaining_amount = #p.remaining_amount and #p'.settled_amount = #p.settled_amount
}

pred NonNegativeRemaining[p: Payment] {
  #p.remaining_amount >= 0
}

pred NonNegativeSettled[p: Payment] {
  #p.settled_amount >= 0
}
