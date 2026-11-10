# Failed How, Exactly?

## Why it works
"Lookup failed" hides four different situations, and nslookup tells them
apart in its messages, not in its exit code:
- **NXDOMAIN**: an authoritative "this name does not exist" (typo,
  decommissioned host). Retrying won't help; fix the name.
- **SERVFAIL**: the server answered but couldn't resolve it, typically a
  broken zone (expired DNSSEC signatures, unreachable or lame authoritative
  servers). Every name in that zone fails the same way.
- **TIMEOUT**: no answer at all: a dead server, a firewall dropping port 53,
  or a server ignoring certain queries. This is the one that makes
  applications hang.

`-timeout=2 -retry=1` kept the silent name from costing 15 seconds.

## Common mistakes
- Using `$?`: it is 1 for NXDOMAIN, SERVFAIL and timeouts alike.
- Matching "Address:" to detect success: nslookup always prints the server's address.
- Treating SERVFAIL as "the name is gone" and deleting monitoring for it.

## Learn next
`dig NAME +short +tries=1 +time=2` prints nothing on failure; plain `dig`
shows the exact `status:` (NOERROR, NXDOMAIN, SERVFAIL, REFUSED) in its header,
which is easier to parse: `dig ... | awk '/status:/ {print $6}'`.
