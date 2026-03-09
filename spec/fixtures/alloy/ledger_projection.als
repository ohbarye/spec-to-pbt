module ledger_projection

sig Ledger {
  entries: seq Int,
  balance: one Int
}

pred PostCredit[l, l': Ledger, amount: Int] {
  #l'.entries = add[#l.entries, 1] and #l'.balance = add[#l.balance, amount]
}

pred PostDebit[l, l': Ledger, amount: Int] {
  #l'.entries = add[#l.entries, 1] and #l'.balance = sub[#l.balance, amount]
}
