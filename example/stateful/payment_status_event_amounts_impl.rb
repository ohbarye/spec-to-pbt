# frozen_string_literal: true

class PaymentStatusEventAmountsImpl
  attr_reader :status, :captures, :remaining_amount, :settled_amount

  def initialize(status: 0, captures: [], remaining_amount: 3, settled_amount: 0)
    @status = status
    @captures = captures.dup
    @remaining_amount = remaining_amount
    @settled_amount = settled_amount
  end

  def open
    raise "invalid transition" unless @status == 0

    @status = 1
    nil
  end

  def settle_unit
    raise "invalid transition" unless @status == 1 && @remaining_amount.positive?

    @captures << 1
    @remaining_amount -= 1
    @settled_amount += 1
    nil
  end

  def close
    raise "invalid transition" unless @status == 1

    @status = 2
    nil
  end
end
