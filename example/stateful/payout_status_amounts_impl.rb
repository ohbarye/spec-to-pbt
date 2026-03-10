# frozen_string_literal: true

class PayoutStatusAmountsImpl
  attr_reader :status, :pending_amount, :paid_amount

  def initialize(status: 0, pending_amount: 0, paid_amount: 0)
    @status = status
    @pending_amount = pending_amount
    @paid_amount = paid_amount
  end

  def queue_amount(amount)
    raise "invalid transition" unless @status == 0 && amount.positive?

    @status = 1
    @pending_amount += amount
    nil
  end

  def complete_amount(amount)
    raise "invalid transition" unless @status == 1 && amount.positive? && amount <= @pending_amount

    @status = 2
    @pending_amount -= amount
    @paid_amount += amount
    nil
  end

  def reset
    raise "invalid transition" unless @status == 2

    @status = 0
    @pending_amount = 0
    @paid_amount = 0
    nil
  end
end
