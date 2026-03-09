module inventory_projection

sig Inventory {
  adjustments: seq Int,
  stock: one Int
}

pred Receive[i, i': Inventory, amount: Int] {
  #i'.adjustments = add[#i.adjustments, 1] and #i'.stock = add[#i.stock, amount]
}

pred Ship[i, i': Inventory, amount: Int] {
  #i'.adjustments = add[#i.adjustments, 1] and #i'.stock = sub[#i.stock, amount]
}
