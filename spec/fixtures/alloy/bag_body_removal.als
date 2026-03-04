module bag

sig Bag {
  elems: seq Int
}

pred TakeFront[b, b': Bag] {
  #b.elems > 0 implies #b'.elems = sub[#b.elems, 1]
}

pred DropLast[b, b': Bag] {
  #b.elems > 0 implies #b'.elems = sub[#b.elems, 1]
}
