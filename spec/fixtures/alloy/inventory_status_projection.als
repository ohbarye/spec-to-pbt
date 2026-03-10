module inventory_status_projection

sig Inventory {
  status: one Int,
  movements: seq Int,
  stock: one Int
}

pred Activate[i, i': Inventory] {
  #i.status = 0 implies #i'.status = 1 and #i'.movements = #i.movements and #i'.stock = #i.stock
}

pred Receive[i, i': Inventory, amount: Int] {
  #i.status = 1 implies #i'.status = #i.status and #i'.movements = add[#i.movements, 1] and #i'.stock = add[#i.stock, amount]
}

pred Deactivate[i, i': Inventory] {
  #i.status = 1 implies #i'.status = 2 and #i'.movements = #i.movements and #i'.stock = #i.stock
}

pred NonNegativeStock[i: Inventory] {
  #i.stock >= 0
}
