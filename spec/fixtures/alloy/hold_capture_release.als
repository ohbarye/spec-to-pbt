module hold_capture_release

sig Reservation {
  available: one Int,
  held: one Int
}

pred Hold[r, r': Reservation, amount: Int] {
  #r.available >= amount implies #r'.available = sub[#r.available, amount] and #r'.held = add[#r.held, amount]
}

pred Capture[r, r': Reservation, amount: Int] {
  #r.held >= amount implies #r'.held = sub[#r.held, amount]
}

pred Release[r, r': Reservation, amount: Int] {
  #r.held >= amount implies #r'.available = add[#r.available, amount] and #r'.held = sub[#r.held, amount]
}

pred NonNegativeAvailable[r: Reservation] {
  #r.available >= 0
}

pred NonNegativeHeld[r: Reservation] {
  #r.held >= 0
}
