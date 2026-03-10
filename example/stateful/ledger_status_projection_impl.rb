# frozen_string_literal: true

class LedgerStatusProjectionImpl
  attr_reader :status, :entries, :balance

  def initialize(status: 0, entries: [], balance: 0)
    @status = status
    @entries = entries.dup
    @balance = balance
  end

  def open
    raise "invalid transition" unless @status == 0

    @status = 1
    nil
  end

  def post_amount(amount)
    raise "invalid transition" unless @status == 1 && amount.positive?

    @entries << amount
    @balance += amount
    nil
  end

  def close
    raise "invalid transition" unless @status == 1

    @status = 2
    nil
  end
end
