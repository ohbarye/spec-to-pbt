# frozen_string_literal: true

class PartialRefundRemainingCapturableImpl
  attr_reader :authorized, :captured, :refunded

  def initialize(authorized: 20, captured: 0, refunded: 0)
    @authorized = authorized
    @captured = captured
    @refunded = refunded
  end

  def capture(amount)
    raise "amount must be positive" if amount <= 0
    raise "insufficient authorized balance" if amount > @authorized

    @authorized -= amount
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
end
