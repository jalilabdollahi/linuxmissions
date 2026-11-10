# Warn the Active Users

## Why it works
`w` shows how long each terminal has been idle, but in whatever unit fits:
seconds with a decimal, `min:sec`, `hours:minutes` followed by `m`, or whole
days. A comparison like `$5 < 10` treats `1:05m` as 1 and `45.00s` as 45,
which is wrong both ways, so each format has to be read for what it means.
`sort -u` merges a user's several sessions into one line.

## Common mistakes
- Converting with `$5+0`: `1:05m` becomes 1 and looks "fresh" although it is
  an hour.
- Dropping a user because *one* of their sessions is stale.
- Treating exactly ten minutes (`10:00`) as active: the rule is "less than".

## Next step
`w -h` hides the header, `w USER` shows one user, and `who -u` gives the
idle time in a simpler form. `pinky` and `last` answer related questions.
