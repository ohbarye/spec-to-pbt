module workflow

sig Machine {
  value: one Int
}

sig Token {}

pred Step[m, m': Machine, t: Token] {
  #m'.value = add[#m.value, 1]
}
