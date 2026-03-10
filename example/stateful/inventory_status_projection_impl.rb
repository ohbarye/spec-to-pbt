# frozen_string_literal: true

class InventoryStatusProjectionImpl
  attr_reader :status, :movements, :stock

  def initialize(status: 0, movements: [], stock: 0)
    @status = status
    @movements = movements.dup
    @stock = stock
  end

  def activate
    raise "invalid transition" unless @status == 0

    @status = 1
    nil
  end

  def receive(amount)
    raise "invalid transition" unless @status == 1 && amount.positive?

    @movements << amount
    @stock += amount
    nil
  end

  def deactivate
    raise "invalid transition" unless @status == 1

    @status = 2
    nil
  end
end
