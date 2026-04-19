# frozen_string_literal: true

class StackImpl
  def initialize
    @values = []
  end

  def push(value)
    @values << value
    nil
  end

  def pop
    @values.shift # BUG: FIFO (first-in first-out) instead of LIFO (last-in first-out)
  end

  def snapshot
    @values.dup
  end
end
