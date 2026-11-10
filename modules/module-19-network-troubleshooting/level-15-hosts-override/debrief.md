# First Match Wins

## Why it works
Programs don't ask DNS directly; they ask the C library, which follows
`/etc/nsswitch.conf`. With `hosts: files dns`, `/etc/hosts` is searched
first, top to bottom, and the first line that lists the name (as canonical
name *or* alias) ends the lookup. Years ago someone added
`db.corp.example` as an alias on the old primary's line, so DNS was never
asked. The colleague's new line at the end of the file was correct but
unreachable. Removing only the alias kept db-a and reports-db (which is not
in DNS) working, and db.corp.example now falls through to the next match.

## Common mistakes
- Trusting `dig`/`nslookup`/`host`: they always ask DNS and ignore
  `/etc/hosts` and nsswitch, so they "prove" everything is fine.
- Grepping without `-w`: `metricsdb.corp.example` contains the string too.
- Deleting the whole line: reports-db.corp.example then stops resolving.
- Swapping nsswitch to `dns files`: that changes every name, including the
  intentional git override.

## Learn next
`getent ahosts NAME` shows every address (IPv4 and IPv6) the resolver
returns. Long-running programs (Java, nscd, systemd-resolved caches) may
keep a stale answer after you fix the file: `resolvectl flush-caches`,
`nscd -i hosts` or a restart clears it. Config management should own
`/etc/hosts`, so hand edits like this don't come back.
