# What's My IP?

## Why it works
In `ip addr` output every interface is a block, and each IPv4 address is an
`inet ADDRESS/PREFIX ... LABEL` line inside it. The label at the end of the
line names the interface that owns the address, so a single awk rule can print
`$NF` and the address without tracking which header line came last. Matching
`$1 == "inet"` (the whole first field) skips `inet6` lines, and the
`secondary` flag shows that one interface can carry several IPv4 addresses.

## Common mistakes
- `grep inet` also matches every `inet6` line.
- Taking the name from the header line (`eno1.120@eno1:`) and forgetting to
  strip the `@parent` part and the colon. VLAN and veth interfaces always show
  their parent that way.

## Learn next
On a live machine: `ip -br -4 addr` prints one line per interface with its
addresses, and `ip -o -4 addr show dev eno1` prints one line per address,
which is easy to feed into awk. `ip route` shows which interface traffic to
each network leaves through.
