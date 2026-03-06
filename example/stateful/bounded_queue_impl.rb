# frozen_string_literal: true

class BoundedQueueImpl
  def initialize(capacity:)
    @capacity = capacity
    @values = []
  end

  def enqueue(value)
    raise "queue full" if @values.length >= @capacity

    @values << value
    nil
  end

  def dequeue
    raise "queue empty" if @values.empty?

    @values.shift
  end

  def snapshot
    @values.dup
  end
end
