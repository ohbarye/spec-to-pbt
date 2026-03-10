# frozen_string_literal: true

class PaymentStatusAmountsImpl
  attr_reader :status, :authorized_amount, :captured_amount

  def initialize(status: 0, authorized_amount: 0, captured_amount: 0)
    @status = status
    @authorized_amount = authorized_amount
    @captured_amount = captured_amount
  end

  def authorize_amount(amount)
    raise "invalid transition" unless @status == 0 && amount.positive?

    @status = 1
    @authorized_amount += amount
    nil
  end

  def capture_amount(amount)
    raise "invalid transition" unless @status == 1 && amount.positive? && amount <= @authorized_amount

    @status = 2
    @authorized_amount -= amount
    @captured_amount += amount
    nil
  end

  def reset
    raise "invalid transition" unless @status == 2

    @status = 0
    @authorized_amount = 0
    @captured_amount = 0
    nil
  end
end
