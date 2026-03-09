module authorization_expiry_void

sig Authorization {
  available: one Int,
  held: one Int
}

pred Authorize[a, a': Authorization, amount: Int] {
  #a.available >= amount implies
    #a'.available = sub[#a.available, amount] and
    #a'.held = add[#a.held, amount]
}

pred Void[a, a': Authorization, amount: Int] {
  #a.held >= amount implies
    #a'.available = add[#a.available, amount] and
    #a'.held = sub[#a.held, amount]
}

pred Expire[a, a': Authorization, amount: Int] {
  #a.held >= amount implies
    #a'.available = add[#a.available, amount] and
    #a'.held = sub[#a.held, amount]
}

pred NonNegativeAvailable[a: Authorization] {
  #a.available >= 0
}

pred NonNegativeHeld[a: Authorization] {
  #a.held >= 0
}
