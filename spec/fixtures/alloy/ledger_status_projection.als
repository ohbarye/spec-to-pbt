module ledger_status_projection

sig Ledger {
  status: one Int,
  entries: seq Int,
  balance: one Int
}

pred Open[l, l': Ledger] {
  #l.status = 0 implies #l'.status = 1 and #l'.entries = #l.entries and #l'.balance = #l.balance
}

pred PostAmount[l, l': Ledger, amount: Int] {
  #l.status = 1 implies #l'.status = #l.status and #l'.entries = add[#l.entries, 1] and #l'.balance = add[#l.balance, amount]
}

pred Close[l, l': Ledger] {
  #l.status = 1 implies #l'.status = 2 and #l'.entries = #l.entries and #l'.balance = #l.balance
}

pred NonNegativeBalance[l: Ledger] {
  #l.balance >= 0
}
