# Big Refunds For Audit

## Why it works
`awk -F,` splits each order into fields, so the filter can look at exactly the
status column instead of the whole line. `tolower($5) == "refunded"` accepts
every capitalisation but compares the *whole* field, so `partially_refunded`
and `refund_pending` stay out. Fields that look like numbers are compared as
numbers, so `$4 > 100` is false for `100.00` and true for `1250.00`.
`NR == 1 ||` lets the header through before the conditions are checked.

## Common mistakes
- `grep -i refunded orders.csv`: it matches `partially_refunded`, and also
  loses the header.
- `$4 >= 100`: "more than" excludes exactly 100.00.
- Comparing with a string such as `$4 > "100"` forces a text comparison, where
  `"99.99" > "100"` is true.

## Learn next
`awk -F, 'NR > 1 { n[tolower($5)]++ } END { for (s in n) print n[s], s }' orders.csv`
counts each status after normalising its case, and `awk -F, -v min=100 '... $4 > min'`
passes the limit in from the shell.
