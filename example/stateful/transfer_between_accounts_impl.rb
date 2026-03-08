# frozen_string_literal: true

class TransferBetweenAccountsImpl
  attr_reader :source_balance, :target_balance

  def initialize(source_balance: 10, target_balance: 0)
    @source_balance = source_balance
    @target_balance = target_balance
  end

  def transfer(amount)
    raise "insufficient source balance" if amount > @source_balance

    @source_balance -= amount
    @target_balance += amount
    nil
  end
end
