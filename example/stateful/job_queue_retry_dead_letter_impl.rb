# frozen_string_literal: true

class JobQueueRetryDeadLetterImpl
  attr_reader :ready, :in_flight, :dead_letter_count

  def initialize(ready: 2, in_flight: 0, dead_letter: 0)
    @ready = ready
    @in_flight = in_flight
    @dead_letter_count = dead_letter
  end

  def enqueue
    @ready += 1
    nil
  end

  def dispatch
    raise "no ready jobs" if @ready <= 0

    @ready -= 1
    @in_flight += 1
    :job
  end

  def ack
    raise "no in-flight jobs" if @in_flight <= 0

    @in_flight -= 1
    nil
  end

  def retry
    raise "no in-flight jobs" if @in_flight <= 0

    @in_flight -= 1
    @ready += 1
    nil
  end

  def move_to_dead_letter
    raise "no in-flight jobs" if @in_flight <= 0

    @in_flight -= 1
    @dead_letter_count += 1
    nil
  end
end
