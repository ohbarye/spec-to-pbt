# frozen_string_literal: true

class PaymentStatusCountersImpl
  attr_reader :status, :authorized, :captured

  def initialize(status: 0, authorized: 0, captured: 0)
    @status = status
    @authorized = authorized
    @captured = captured
  end

  def authorize_one
    raise "invalid transition" unless @status == 0

    @status = 1
    @authorized += 1
    nil
  end

  def capture_one
    raise "invalid transition" unless @status == 1 && @authorized.positive?

    @status = 2
    @authorized -= 1
    @captured += 1
    nil
  end

  def reset
    raise "invalid transition" unless @status == 2

    @status = 0
    @authorized = 0
    @captured = 0
    nil
  end
end
