# frozen_string_literal: true

class JobStatusEventCountersImpl
  attr_reader :status, :events, :retry_budget, :retry_count

  def initialize(status: 0, events: [], retry_budget: 3, retry_count: 0)
    @status = status
    @events = events.dup
    @retry_budget = retry_budget
    @retry_count = retry_count
  end

  def activate
    raise "invalid transition" unless @status == 0

    @status = 1
    nil
  end

  def retry
    raise "invalid transition" unless @status == 1 && @retry_budget.positive?

    @events << 1
    @retry_budget -= 1
    @retry_count += 1
    nil
  end

  def deactivate
    raise "invalid transition" unless @status == 1

    @status = 2
    nil
  end
end
