module job_queue_retry_dead_letter {
  var ready: int
  var in_flight: int
  var dead_letter: int

  action Enqueue = all {
    ready' = ready + 1,
    in_flight' = in_flight,
    dead_letter' = dead_letter,
  }

  action Dispatch = all {
    ready > 0,
    ready' = ready - 1,
    in_flight' = in_flight + 1,
    dead_letter' = dead_letter,
  }

  action Ack = all {
    in_flight > 0,
    ready' = ready,
    in_flight' = in_flight - 1,
    dead_letter' = dead_letter,
  }

  action Retry = all {
    in_flight > 0,
    ready' = ready + 1,
    in_flight' = in_flight - 1,
    dead_letter' = dead_letter,
  }

  action DeadLetter = all {
    in_flight > 0,
    ready' = ready,
    in_flight' = in_flight - 1,
    dead_letter' = dead_letter + 1,
  }

  val NonNegativeReady = ready >= 0
}
