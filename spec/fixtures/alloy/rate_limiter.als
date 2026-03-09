module rate_limiter

sig Limiter {
  remaining: one Int,
  capacity: one Int
}

pred Allow[l, l': Limiter] {
  #l.remaining > 0 implies
    #l'.remaining = sub[#l.remaining, 1]
}

pred Reset[l, l': Limiter] {
  #l'.remaining = #l.capacity
}

pred NonNegativeRemaining[l: Limiter] {
  #l.remaining >= 0
}
