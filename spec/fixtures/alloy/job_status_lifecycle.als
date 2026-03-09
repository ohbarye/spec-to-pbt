module job_status_lifecycle

sig Job {
  status: one Int
}

pred Start[j, j': Job] {
  #j.status = 0 implies #j'.status = 1
}

pred Complete[j, j': Job] {
  #j.status = 1 implies #j'.status = 2
}

pred Fail[j, j': Job] {
  #j.status = 1 implies #j'.status = 3
}

pred DeadLetter[j, j': Job] {
  #j.status = 3 implies #j'.status = 4
}
