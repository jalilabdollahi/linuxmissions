# Passwords About to Expire

## Why it works
`/etc/shadow` stores ageing in **days since 1970-01-01**: field 3 is the last change, field 4 the
minimum age, field 5 the maximum age, field 6 the warning, field 8 the *account* expiry. A password
expires on day `last change + max age`, so the review is date arithmetic in one unit: compute today as
`epoch seconds / 86400`, keep what is at or below today + 14, sort numerically and only then turn
the day numbers into dates with `date -u -d "1970-01-01 +N days" +%F`.

The special values matter: `99999` as maximum means never, an empty max or last-change field turns
ageing off, and a last change of `0` forces a new password at the next login (`chage -l` says
"password must be changed"), so it counts as expired now.

## Common mistakes
- Using field 8: that is when the whole **account** expires, not the password.
- Treating `99999` or empty fields as large dates and getting nonsense, or skipping the `0` case.
- Sorting the converted dates as text is fine for ISO dates, but sorting day numbers as text is not
  (use `sort -n`).
- Comparing against the real date today instead of the ticket date.

## Next step
`chage -l user` reads the same data for one account; `sudo chage -M 90 -W 14 user` sets the
policy, and `passwd -e user` forces a change at the next login (it sets the last-change field to 0).
