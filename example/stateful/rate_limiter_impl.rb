# frozen_string_literal: true

class RateLimiterImpl
  attr_reader :remaining, :capacity

  def initialize(capacity: 3, remaining: capacity)
    @capacity = capacity
    @remaining = remaining
  end

  def allow
    raise "quota exhausted" if @remaining <= 0

    @remaining -= 1
    true
  end

  def reset
    @remaining = @capacity
    nil
  end
end
