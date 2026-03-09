module payment_status_lifecycle

sig Payment {
  status: one Int
}

pred Authorize[p, p': Payment] {
  #p.status = 0 implies #p'.status = 1
}

pred Capture[p, p': Payment] {
  #p.status = 1 implies #p'.status = 2
}

pred Void[p, p': Payment] {
  #p.status = 1 implies #p'.status = 3
}

pred Refund[p, p': Payment] {
  #p.status = 2 implies #p'.status = 4
}
