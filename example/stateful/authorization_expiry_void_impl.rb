# frozen_string_literal: true

class AuthorizationExpiryVoidImpl
  attr_reader :available, :held

  def initialize(available: 20, held: 0)
    @available = available
    @held = held
  end

  def authorize(amount)
    raise "amount must be positive" if amount <= 0
    raise "insufficient available balance" if amount > @available

    @available -= amount
    @held += amount
    nil
  end

  def void_authorization(amount)
    raise "amount must be positive" if amount <= 0
    raise "insufficient held balance" if amount > @held

    @available += amount
    @held -= amount
    nil
  end

  def expire_authorization(amount)
    raise "amount must be positive" if amount <= 0
    raise "insufficient held balance" if amount > @held

    @available += amount
    @held -= amount
    nil
  end
end
