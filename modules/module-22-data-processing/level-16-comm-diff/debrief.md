# License Reconciliation

## Why it works
`comm` compares two sorted files line by line and prints three columns: lines only in
the first, lines only in the second, and lines in both. Suppressing columns turns it
into set operations: `-12` is the intersection, `-23` is "first minus second",
`-13` is "second minus first". The hard part is not comm but making the three sources
agree on what a username looks like: lowercase, no padding, one line per user, sorted
in the same order. Once each source is a clean sorted list, the whole reconciliation
is three comm calls.

## Common mistakes
- Comparing raw files: `Jdoe ` (with a space) and `jdoe` are different lines, so the
  same person shows up as both an unused seat and an unlicensed user.
- Forgetting the enabled check: logins of people who left are in the log from before
  their account was disabled. Their seat is free now.
- `awk '{print $6}'` for the user: on lines with `mfa=` the user is one field later.
  `grep -o 'user=[^ ]*'` finds it anywhere.
- Sorting in one locale and running comm in another: comm then reports
  "file 1 is not in sorted order" and its output can't be trusted.

## Learn next
`comm` needs sorted input; `grep -Fxv -f B A` gives "A minus B" without sorting
(but slowly for big files). For counts per set, `comm -3 A B | wc -l` is the size of
the symmetric difference.
