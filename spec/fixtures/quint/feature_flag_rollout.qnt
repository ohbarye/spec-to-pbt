module feature_flag_rollout {
  var rollout: int
  var max_rollout: int

  action Enable = all {
    rollout' = max_rollout,
    max_rollout' = max_rollout,
  }

  action Disable = all {
    rollout' = 0,
    max_rollout' = max_rollout,
  }

  action Rollout(percent) = all {
    max_rollout >= percent,
    rollout' = percent,
    max_rollout' = max_rollout,
  }

  val RolloutBounded = rollout >= 0
}
