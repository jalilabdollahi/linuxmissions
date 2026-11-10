# Dormant Accounts

## Why it works
`lastlog` reads `/var/log/lastlog`, a binary file indexed by UID, and prints one
fixed-width row per account: name, port, source host and the time of the last login
(`**Never logged in**` if there is none). Fixed widths are what make `cut -c44-`
reliable where `awk '{print $4}'` is not: Port and From can be empty, and dates such
as `Aug  4` contain two spaces. `date -u -d` understands the full timestamp, offset
included, and `+%F` turns it into a sortable `YYYY-MM-DD`, so the cut-off is a string
comparison.

## Common mistakes
- Comparing local dates: a login at `Aug 12 23:30 -0500` is already Aug 13 in UTC and
  is not dormant, while `Aug 13 01:30 +0200` is still Aug 12 in UTC and is.
- Forgetting accounts that lastlog does not mention at all (they never logged in).
- Including system accounts or `nobody`: the review covers regular UIDs only.

## Next step
`lastlog -b 90` lists accounts whose last login is *older* than 90 days and
`lastlog -t 90` those *newer* than it. Both rely on the log's local clock, which is why
this level asked for UTC. The login *history* (not just the last login) is in `last`.
