module job_queue_retry_dead_letter

sig Jobs {
  ready: one Int,
  in_flight: one Int,
  dead_letter: one Int
}

pred Enqueue[j, j': Jobs] {
  #j'.ready = add[#j.ready, 1]
}

pred Dispatch[j, j': Jobs] {
  #j.ready > 0 implies
    #j'.ready = sub[#j.ready, 1] and
    #j'.in_flight = add[#j.in_flight, 1]
}

pred Ack[j, j': Jobs] {
  #j.in_flight > 0 implies
    #j'.in_flight = sub[#j.in_flight, 1]
}

pred Retry[j, j': Jobs] {
  #j.in_flight > 0 implies
    #j'.ready = add[#j.ready, 1] and
    #j'.in_flight = sub[#j.in_flight, 1]
}

pred DeadLetter[j, j': Jobs] {
  #j.in_flight > 0 implies
    #j'.in_flight = sub[#j.in_flight, 1] and
    #j'.dead_letter = add[#j.dead_letter, 1]
}

pred NonNegativeReady[j: Jobs] {
  #j.ready >= 0
}
