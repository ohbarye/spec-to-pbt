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

  def debit(amount)
    raise "amount must be positive" if amount <= 0
    raise "insufficient funds" if amount > @balance

    @balance -= amount
    nil
  end
end
