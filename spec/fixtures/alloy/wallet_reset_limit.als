module wallet_reset_limit

sig Wallet {
  balance: one Int,
  credit_limit: one Int
}

pred ResetToLimit[w, w': Wallet] {
  #w'.balance = #w.credit_limit
}

pred NonNegative[w: Wallet] {
  #w.balance >= 0
}
