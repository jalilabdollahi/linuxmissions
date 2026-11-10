# First Come Within Priority

## Why it works
`-k2,2` makes the priority the only sort key. When two lines have equal keys,
GNU sort normally runs a *last-resort comparison* of the whole lines, so P2
tickets end up ordered by their random id. `-s` (stable) switches that off:
lines with equal keys stay in the order they were read, which is the arrival
order.

## Common mistakes
- `sort -k2`: the key runs from field 2 to the end of the line, so tickets of
  the same priority are ordered by customer and subject.
- Sorting on a time column you added later: works, but a stable sort needs no
  extra data.
- `sort -s` with no `-k`: the key is the whole line, so stability changes
  nothing.

## Learn next
`sort --debug -s -k2,2 queue.txt` underlines the key sort uses on each line.
Stability matters every time you sort in several passes: sort by the minor key
first, then `sort -s` by the major key, and the minor order survives.
