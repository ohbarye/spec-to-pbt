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
    @values.pop
  end

  def snapshot
    @values.dup
  end
end
