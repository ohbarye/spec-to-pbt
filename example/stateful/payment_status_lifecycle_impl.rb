# frozen_string_literal: true

class PaymentStatusLifecycleImpl
  attr_reader :status

  def initialize(status: 0)
    @status = status
  end

  def authorize
    raise "invalid transition" unless @status == 0

    @status = 1
    nil
  end

  def capture
    raise "invalid transition" unless @status == 1

    @status = 2
    nil
  end

  def void
    raise "invalid transition" unless @status == 1

    @status = 3
    nil
  end

  def refund
    raise "invalid transition" unless @status == 2

    @status = 4
    nil
  end
end
