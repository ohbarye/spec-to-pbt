# frozen_string_literal: true

class BankAccountImpl
  attr_reader :balance

  def initialize
    @balance = 0
  end

  def credit(amount)
    raise "amount must be positive" if amount <= 0

    @balance += amount
    nil
  end

  def debit
    raise "insufficient funds" if @balance <= 0

    @balance -= 1
    nil
  end
end
