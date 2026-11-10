# Name Resolution

## Why it works
`dig +short` prints the answer section's data only: for `www.internal` that is
the CNAME target `app-lb.internal.` followed by its A record, and for
`api.internal` two A records. Keeping only lines that look like IPv4 addresses
gives exactly the final addresses, one per line. A name that does not exist
returns no data at all (status NXDOMAIN in the full output), which the empty
check turns into the `NXDOMAIN` marker.

## Common mistakes
- `echo "$host $(dig +short "$host")"`: fine for a simple A record, but a
  CNAME puts the alias name into the file and two A records end up on one line.
- Expecting dig to fail on NXDOMAIN: dig exits 0 whenever it got *an* answer
  from the server, even "this name does not exist". Check the data or the
  status, not the exit code.

## Learn next
`dig +noall +answer NAME` prints just the answer records with TTLs,
`dig -t MX mail.internal` asks for another record type, and
`dig @10.20.4.2 NAME` queries a specific server, which is how you compare what
two DNS servers say. `getent hosts NAME` shows what the system resolver
(including /etc/hosts) returns.
