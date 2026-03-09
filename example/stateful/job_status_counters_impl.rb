# frozen_string_literal: true

class JobStatusCountersImpl
  attr_reader :status, :retry_count, :dead_letter_count

  def initialize(status: 0, retry_count: 0, dead_letter_count: 0)
    @status = status
    @retry_count = retry_count
    @dead_letter_count = dead_letter_count
  end

  def dispatch
    raise "invalid transition" unless @status == 0

    @status = 1
    nil
  end

  def requeue
    raise "invalid transition" unless @status == 1

    @status = 0
    @retry_count += 1
    nil
  end

  def move_to_dead_letter
    raise "invalid transition" unless @status == 1

    @status = 2
    @dead_letter_count += 1
    nil
  end
end
