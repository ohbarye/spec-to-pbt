module wallet_with_limit

sig Wallet {
  balance: one Int,
  credit_limit: one Int
}

pred Deposit[w, w': Wallet] {
  #w'.balance = add[#w.balance, 1]
}

pred Withdraw[w, w': Wallet] {
  #w.balance > 0 implies #w'.balance = sub[#w.balance, 1]
}

pred NonNegative[w: Wallet] {
  #w.balance >= 0
}
