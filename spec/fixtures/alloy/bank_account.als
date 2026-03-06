module bank_account

sig Account {
  balance: one Int
}

pred Deposit[a, a': Account] {
  #a'.balance = #a.balance + 1
}

pred DepositAmount[a, a': Account, amount: Int] {
  #a'.balance = add[#a.balance, amount]
}

pred Withdraw[a, a': Account] {
  #a.balance > 0 implies #a'.balance = #a.balance - 1
}

pred WithdrawAmount[a, a': Account, amount: Int] {
  #a.balance >= amount implies #a'.balance = sub[#a.balance, amount]
}

pred DepositWithdrawIdentity[a, a': Account] {
  #a'.balance = #a.balance
}

pred NonNegative[a: Account] {
  #a.balance >= 0
}

assert AccountProperties {
  all a, a': Account |
    Deposit[a, a'] and
    (#a.balance > 0 implies Withdraw[a, a'])
}
