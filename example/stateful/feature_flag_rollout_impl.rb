# frozen_string_literal: true

class FeatureFlagRolloutImpl
  attr_reader :rollout, :max_rollout

  def initialize(max_rollout: 100, rollout: 0)
    @max_rollout = max_rollout
    @rollout = rollout
  end

  def enable_globally
    @rollout = @max_rollout
    nil
  end

  def disable_globally
    @rollout = 0
    nil
  end

  def set_rollout(percent)
    raise "percent must be within rollout bounds" if percent.negative? || percent > @max_rollout

    @rollout = percent
    nil
  end
end
