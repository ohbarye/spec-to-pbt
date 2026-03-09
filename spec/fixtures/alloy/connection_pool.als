module connection_pool

sig Pool {
  available: one Int,
  checked_out: one Int,
  capacity: one Int
}

pred Checkout[p, p': Pool] {
  #p.available > 0 implies
    #p'.available = sub[#p.available, 1] and
    #p'.checked_out = add[#p.checked_out, 1]
}

pred Checkin[p, p': Pool] {
  #p.checked_out > 0 implies
    #p'.available = add[#p.available, 1] and
    #p'.checked_out = sub[#p.checked_out, 1]
}

pred CapacityPreserved[p: Pool] {
  add[#p.available, #p.checked_out] = #p.capacity
}
