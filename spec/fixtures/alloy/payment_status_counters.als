module payment_status_counters

sig Payment {
  status: one Int,
  authorized: one Int,
  captured: one Int
}

pred AuthorizeOne[p, p': Payment] {
  #p.status = 0 implies #p'.status = 1 and #p'.authorized = add[#p.authorized, 1] and #p'.captured = #p.captured
}

pred CaptureOne[p, p': Payment] {
  #p.status = 1 and #p.authorized > 0 implies #p'.status = 2 and #p'.authorized = sub[#p.authorized, 1] and #p'.captured = add[#p.captured, 1]
}

pred Reset[p, p': Payment] {
  #p.status = 2 implies #p'.status = 0 and #p'.authorized = 0 and #p'.captured = 0
}
