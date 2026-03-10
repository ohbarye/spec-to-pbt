module job_status_event_counters

sig Job {
  status: one Int,
  events: seq Int,
  retry_budget: one Int,
  retry_count: one Int
}

pred Activate[j, j': Job] {
  #j.status = 0 implies #j'.status = 1 and #j'.events = #j.events and #j'.retry_budget = #j.retry_budget and #j'.retry_count = #j.retry_count
}

pred Retry[j, j': Job] {
  #j.status = 1 and #j.retry_budget > 0 implies #j'.status = #j.status and #j'.events = add[#j.events, 1] and #j'.retry_budget = sub[#j.retry_budget, 1] and #j'.retry_count = add[#j.retry_count, 1]
}

pred Deactivate[j, j': Job] {
  #j.status = 1 implies #j'.status = 2 and #j'.events = #j.events and #j'.retry_budget = #j.retry_budget and #j'.retry_count = #j.retry_count
}

pred NonNegativeBudget[j: Job] {
  #j.retry_budget >= 0
}

pred NonNegativeRetries[j: Job] {
  #j.retry_count >= 0
}
