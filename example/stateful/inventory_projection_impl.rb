# frozen_string_literal: true

class InventoryProjectionImpl
  attr_reader :adjustments, :stock

  def initialize(adjustments: [], stock: 0)
    @adjustments = adjustments.dup
    @stock = stock
  end

  def receive(amount)
    raise "amount must be positive" if amount <= 0

    @adjustments << amount
    @stock += amount
    nil
  end

  def ship(amount)
    raise "amount must be positive" if amount <= 0

    @adjustments << -amount
    @stock -= amount
    nil
  end
end
