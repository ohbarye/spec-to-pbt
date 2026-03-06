module thermostat

sig Thermostat {
  target: one Int
}

pred SetTarget[t, t': Thermostat, next: Int] {
  #t'.target = next
}
