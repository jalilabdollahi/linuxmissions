# Prod vs Staging Drift

## Why it works
`join` pairs lines with the same key, but only when the key is spelled the same and both inputs
are sorted the same way. The two dumps used a tab and a space, and one wrote `libc6:amd64` where
the other wrote `libc6`, so a plain `join` found nothing in common. Normalising first (awk splits
on any blanks and `sub()` strips the suffix) turns the task into an ordinary outer join:
`-a1 -a2` keeps the unmatched lines of both sides, `-e -` fills the empty side with a dash, and
filtering on `$2 != $3` leaves exactly the drift.

## Common mistakes
- Sorting with one locale and joining with another: `join` then warns "not in sorted order" or
  silently drops pairs. Set `LC_ALL=C` for both steps.
- Comparing whole lines with `comm`: a changed version makes the line differ, but you lose the
  package-level view (the same name appears once on each side).
- Forgetting packages that exist only on staging.

## Next step
`comm -23 a b` / `comm -13 a b` give the lines unique to each sorted file, and `diff <(cut -f1 a) <(cut -f1 b)`
is a quick check of which names differ. `dpkg-query -W -f='${binary:Package}\t${Version}\n'` makes the same format on every server.
