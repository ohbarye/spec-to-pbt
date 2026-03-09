# frozen_string_literal: true

class ConnectionPoolImpl
  attr_reader :available, :checked_out, :capacity

  def initialize(capacity: 3, available: capacity, checked_out: 0)
    @capacity = capacity
    @available = available
    @checked_out = checked_out
  end

  def checkout
    raise "pool exhausted" if @available <= 0

    @available -= 1
    @checked_out += 1
    :connection
  end

  def checkin
    raise "nothing checked out" if @checked_out <= 0

    @available += 1
    @checked_out -= 1
    nil
  end
end
