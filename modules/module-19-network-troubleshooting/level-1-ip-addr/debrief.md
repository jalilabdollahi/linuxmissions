# Which Leg Is the Database?

## Why it works
A /22 has 22 network bits, so the last 10 bits are hosts: 10.20.0.0/22 runs
from 10.20.0.0 to 10.20.3.255. That makes `10.20.3.x` part of it and
`10.20.4.x` and `10.20.5.x` (the next /22, primary and `secondary` on
ens6f0) not, even though they all "look like" 10.20. The right address was the
second one on the VLAN interface `bond0.N`, whose first address is in another
subnet, so a quick look at the first `inet` line of each interface misses it.
(Linux only marks an address `secondary` when the interface already has one in
the same subnet; an address in a new subnet is a primary of its own.) In `bond0.N@bond0` the `@bond0` only names the parent link. The state
comes from the VLAN's own header line. When it says `LOWERLAYERDOWN`, the VLAN
itself is up but the bond under it has no carrier, so the app can bind to the
address but nothing reaches the database.

## Common mistakes
- Treating the third octet as fixed: that only works for /24 networks.
- Writing `bond0.N@bond0` as the name: `ip addr show dev bond0.N@bond0` fails.
- Taking the state of `bond0` or a slave NIC instead of the interface that has the address.

## Learn next
`ip -br addr` prints one line per interface (name, state, addresses), and
`ip -j addr | jq` gives JSON you can query safely. To check subnet membership
without doing the bit maths in your head:
`python3 -c 'import ipaddress as i; print(i.ip_address("10.20.3.9") in i.ip_network("10.20.0.0/22"))'`.
