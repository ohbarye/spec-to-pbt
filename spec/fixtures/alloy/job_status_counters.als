module job_status_counters

sig Job {
  status: one Int,
  retry_count: one Int,
  dead_letter_count: one Int
}

pred Start[j, j': Job] {
  #j.status = 0 implies #j'.status = 1 and #j'.retry_count = #j.retry_count and #j'.dead_letter_count = #j.dead_letter_count
}

pred Retry[j, j': Job] {
  #j.status = 1 implies #j'.status = 0 and #j'.retry_count = add[#j.retry_count, 1] and #j'.dead_letter_count = #j.dead_letter_count
}

pred DeadLetter[j, j': Job] {
  #j.status = 1 implies #j'.status = 2 and #j'.retry_count = #j.retry_count and #j'.dead_letter_count = add[#j.dead_letter_count, 1]
}
