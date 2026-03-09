# frozen_string_literal: true

class LedgerProjectionImpl
  attr_reader :entries, :balance

  def initialize(entries: [], balance: 0)
    @entries = entries.dup
    @balance = balance
  end

  def post_credit(amount)
    raise "amount must be positive" if amount <= 0

    @entries << amount
    @balance += amount
    nil
  end

  def post_debit(amount)
    raise "amount must be positive" if amount <= 0

    @entries << -amount
    @balance -= amount
    nil
  end
end
