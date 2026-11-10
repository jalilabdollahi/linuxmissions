# Capacity Review

## Why it works
Each `-k` is one sort key, tried in order: a later key only matters when all
earlier keys are equal. `-k2,2` limits the first key to the datacenter field;
`-k4,4gr` compares loads with `strtod`, so `1e-02` is 0.01 and `1.2e+01` is
12, and `r` reverses only that key. `-k1,1V` compares runs of digits as
numbers, so `web9` comes before `web10`. `head -1` and `tail -n +2` keep the
header out of the sort.

## Common mistakes
- `-k2` without `,2`: the key runs from field 2 to the end of the line, so
  inside a datacenter the rack decides and the load key never gets a say.
- `-n` instead of `-g`: `-n` stops at the `e`, so `1.2e+01` sorts as 1.2.
  `-g` is slower, so use it only when the data really has exponents.
- Global flags vs key flags: `sort -r -k2,2 -k4,4g` reverses every key; put
  the `r` on the key that needs it.

## Learn next
`sort -s` (stable) keeps the input order for lines whose keys are all equal,
instead of comparing whole lines as a last resort. `sort --debug` (GNU)
underlines the part of each line that every key used: the quickest way to see
why a key does not do what you meant.
