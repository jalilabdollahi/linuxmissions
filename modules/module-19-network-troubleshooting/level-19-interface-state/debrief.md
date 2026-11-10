# Deltas, Not Totals

## Why it works
Interface counters are cumulative since boot, so the interface with the
largest CRC total was simply broken at some point in the past (its counters
didn't move in these 60 seconds). Subtracting the first capture from the
second showed what is happening *now*: one storage port's `transns` (carrier
transitions, the same value as `/sys/class/net/IF/carrier_changes`) grew, so
its link went down and up between the captures, and its CRC errors grew with
it: a bad cable, optic or switch port. The 1G port at `speed 100` / `duplex
half` is a classic duplex mismatch (one side autonegotiated, the other was
forced to full), which shows up as growing collisions and window (late
collision) errors on the half-duplex side and CRC errors on the switch.

## Common mistakes
- Ranking interfaces by total errors instead of by change: the "worst"
  interface was old news.
- Blaming an admin-down interface: `duplex unknown` and `speed -1` are
  normal for a port with no link.
- Reading `operstate` once and calling the link fine: a flapping link is
  `up` most of the time.

## Learn next
`ethtool IFACE` shows speed, duplex and autonegotiation, and `ethtool -S
IFACE` the driver's own counters (often `rx_crc_errors`, `link_down_events`).
`ip -s -s link` twice with `sleep 60` in between, or `sar -n EDEV 1`,
gives you the deltas directly. `ip monitor link` prints every carrier change
as it happens.
