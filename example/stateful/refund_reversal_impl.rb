# frozen_string_literal: true

class RefundReversalImpl
  attr_reader :captured, :refunded

  def initialize(captured: 0, refunded: 0)
    @captured = captured
    @refunded = refunded
  end

  def capture(amount)
    raise "amount must be positive" if amount <= 0

    @captured += amount
    nil
  end

  def refund(amount)
    raise "amount must be positive" if amount <= 0
    raise "insufficient captured balance" if amount > @captured

    @captured -= amount
    @refunded += amount
    nil
  end

  def reverse(amount)
    raise "amount must be positive" if amount <= 0
    raise "insufficient refunded balance" if amount > @refunded

    @captured += amount
    @refunded -= amount
    nil
  end
end
