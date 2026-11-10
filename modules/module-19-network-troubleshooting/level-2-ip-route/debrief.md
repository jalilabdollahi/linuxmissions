# Which Way Out?

## Why it works
Linux chooses a route by longest-prefix match: of all routes whose network
contains the destination, the most specific wins, whatever order `ip route`
prints them in. So the host route `10.50.X.Y via ...` (a bare address is a /32)
beats `10.50.0.0/16`, which is listed first; `10.50.Z.0/24 dev ens4 scope link`
sends that subnet out of ens4 without a gateway; and an address only the
default route covers goes to the default gateway. The look-alikes were the
trap: 10.5.0.0/16 doesn't contain 10.50.x.x, 10.99.0.0/20 stops at 10.99.15.255,
and 172.16.0.0/12 stops at 172.31.255.255.

## Common mistakes
- Taking the first matching line, as `grep` or `awk ... exit` would.
- Comparing addresses as text: `10.50` starts with `10.5`, but they are different networks.
- Reading the gateway's own host route (`10.0.a.1 dev ens3 scope link`) as a route via something: it just says the gateway is directly reachable.

## Learn next
On a live host, `ip route get ADDRESS` runs the real lookup (add `from SRC` or
`mark N` to test policy routing), and `ip route show table all` reveals extra
tables used by `ip rule`, which matter when one host has several uplinks.
