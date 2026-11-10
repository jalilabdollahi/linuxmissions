# Quota Report

## Why it works
Bash arithmetic only knows whole numbers, and it reads numbers the way C
does: a leading `0` means octal. `08` and `00921600` are errors ("value too
great for base"), and worse, `00755000` is silently read as 252416. `10#$n`
forces base 10 for one value. Integer division drops the remainder, so
`used / quota * 100` is 0 for everyone under 100 %; multiplying first keeps
the precision. Adding all sizes in KiB and dividing by 1024 once gives the
real total: dividing per user throws away up to 1023 KiB per line.

## Common mistakes
- `$((10#$n))` on an empty field is an error; check the data or use `${n:-0}`.
- `${n#0}` removes only one zero, `0089` becomes `089`, still octal.
- Testing `(( pct > 90 ))` when the rule says "at least 90".

## Learn next
Bash has no fractions: for `93.7 %` use `awk '{ printf "%.1f", $2*100/$3 }'`
or `bc`. `printf '%08d' 42` produces the zero padding in the first place,
and `printf -v var` stores the result in a variable without a subshell.
