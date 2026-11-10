# One in Three

## Why it works
With `options rotate`, glibc spreads lookups round-robin over the
nameservers, so a single bad server out of three breaks about every third
lookup, and a retry lands on a good one: the classic "intermittent DNS"
pattern. Spot checks with a name that never changed (www) look fine
everywhere. The SOA serial is the zone's version number: the primary bumps
it on every change and secondaries copy the zone when their serial is
lower. One secondary's serial was a week behind, so it never got the
migration (pay-v2 missing → NXDOMAIN, which is final and not retried;
checkout still at its old, switched-off address). Removing it from
resolv.conf stops the bleeding until the DNS team fixes the zone transfer.

## Common mistakes
- Testing only through the resolver (`getent`, `ping name`): you never
  know which server answered. Ask each server with `dig @server`.
- Expecting the resolver to try the next server after NXDOMAIN: it doesn't;
  only timeouts and SERVFAIL move on.
- Checking an unchanged record and declaring DNS healthy.

## Learn next
`dig +nssearch corp.example` asks every NS for the SOA in one go (in real
DNS). A stale secondary usually means a failing zone transfer (AXFR/IXFR):
check NOTIFY, the primary's `allow-transfer`, and the secondary's logs.
Monitoring that alerts when secondaries' serials differ from the primary's
for longer than the refresh interval would have caught this a week ago.
