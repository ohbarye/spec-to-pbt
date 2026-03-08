# frozen_string_literal: true

class HoldCaptureReleaseImpl
  attr_reader :available, :held

  def initialize(available: 10, held: 0)
    @available = available
    @held = held
  end

  def hold(amount)
    raise "insufficient available balance" if amount > @available

    @available -= amount
    @held += amount
    nil
  end

  def capture(amount)
    raise "insufficient held balance" if amount > @held

    @held -= amount
    nil
  end

  def release(amount)
    raise "insufficient held balance" if amount > @held

    @available += amount
    @held -= amount
    nil
  end
end
