module transfer_between_accounts

sig Accounts {
  source_balance: one Int,
  target_balance: one Int
}

pred Transfer[a, a': Accounts, amount: Int] {
  #a.source_balance >= amount implies #a'.source_balance = sub[#a.source_balance, amount] and #a'.target_balance = add[#a.target_balance, amount]
}

pred NonNegativeSource[a: Accounts] {
  #a.source_balance >= 0
}

pred NonNegativeTarget[a: Accounts] {
  #a.target_balance >= 0
}
