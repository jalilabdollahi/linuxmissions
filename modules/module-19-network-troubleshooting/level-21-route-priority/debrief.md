# Which Way Out?

## Why it works
Linux routes in two stages. The rules (`ip rule`) are tried by priority, and
the first one whose selectors match picks a table. Only inside that table
does longest-prefix matching happen, with the metric as tie-breaker. So:

- The wiki on the old office subnet went over the VPN although `main` has a
  more specific /24 for it via the office router: rule 32765 (to the corp
  /16) is checked before `main` (32766), and table lookups never compare
  routes across tables.
- Traffic from the VPN address to the internet matched rule 32764, but the
  VPN table has no default route, so the kernel fell through to the next
  rules and finally used `main`'s default.
- The Wi-Fi-bound app still left through whichever default route has the
  lower metric: in `main`, the source address doesn't pick the interface.
  (That's why multihomed hosts add `from <addr> lookup <table>` rules.)

## Common mistakes
- Reading ip-route-all.txt top to bottom and taking the first match.
- Assuming the most specific route in *any* table wins.
- Forgetting that `ip route show` without `table all` shows only `main`, so
  the VPN routes are invisible there.

## Learn next
On a live system, `ip route get 140.82.1.1 from 10.9.0.25` prints the
decision (and `ip route get ... mark 0x1` for fwmark rules). wg-quick's
full-tunnel setup is worth reading: it adds `not fwmark 51820 lookup 51820`
plus `lookup main suppress_prefixlength 0`, so main's specific routes still
win while its default route is ignored.
