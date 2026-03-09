# frozen_string_literal: true

class JobStatusLifecycleImpl
  attr_reader :status

  def initialize(status: 0)
    @status = status
  end

  def start
    raise "invalid transition" unless @status == 0

    @status = 1
    nil
  end

  def complete
    raise "invalid transition" unless @status == 1

    @status = 2
    nil
  end

  def mark_failed
    raise "invalid transition" unless @status == 1

    @status = 3
    nil
  end

  def move_to_dead_letter
    raise "invalid transition" unless @status == 3

    @status = 4
    nil
  end
end
