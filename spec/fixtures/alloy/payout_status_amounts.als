module payout_status_amounts

sig Payout {
  status: one Int,
  pending_amount: one Int,
  paid_amount: one Int
}

pred QueueAmount[p, p': Payout, amount: Int] {
  #p.status = 0 implies #p'.status = 1 and #p'.pending_amount = add[#p.pending_amount, amount] and #p'.paid_amount = #p.paid_amount
}

pred CompleteAmount[p, p': Payout, amount: Int] {
  #p.pending_amount >= amount implies #p'.status = 2 and #p'.pending_amount = sub[#p.pending_amount, amount] and #p'.paid_amount = add[#p.paid_amount, amount]
}

pred Reset[p, p': Payout] {
  #p.status = 2 implies #p'.status = 0 and #p'.pending_amount = 0 and #p'.paid_amount = 0
}

pred NonNegativePending[p: Payout] {
  #p.pending_amount >= 0
}

pred NonNegativePaid[p: Payout] {
  #p.paid_amount >= 0
}
