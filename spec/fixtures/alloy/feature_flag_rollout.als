module feature_flag_rollout

sig Flag {
  rollout: one Int,
  max_rollout: one Int
}

pred Enable[f, f': Flag] {
  #f'.rollout = #f.max_rollout
}

pred Disable[f, f': Flag] {
  #f'.rollout = 0
}

pred Rollout[f, f': Flag, percent: Int] {
  #f.max_rollout >= percent implies
    #f'.rollout = #percent
}

pred RolloutBounded[f: Flag] {
  #f.rollout >= 0
}
