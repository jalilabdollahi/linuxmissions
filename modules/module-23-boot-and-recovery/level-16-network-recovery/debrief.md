# Boots Without Network

## Why it works
systemd-networkd applies the first `.network` file (in name order) whose `[Match]` section
fits a link. After the board swap nothing fitted: `eno1` was gone, the new NICs are
called `enp3s0`-style names, and the other file matched the MAC address of the old board.
You looked up each new NIC by its MAC in the captured `ip -o link`, and pointed each file at
it. The LAN file had a second fault: `/25` covers only 128 addresses, so the gateway was
outside the subnet and networkd could not install the default route. Using the ticket's
prefix fixed it, and the backup network stayed without a gateway.

## Common mistakes
- Fixing `Name=` but not the prefix: the interface comes up and still has no route out.
- Matching both NICs from one file (`Name=enp*`): the first file wins for both.
- Putting a `Gateway=` on the backup NIC and getting two default routes.

## Next step
`networkctl list` and `networkctl status <link>` show which file a live link uses
(module 19 does live troubleshooting), and a `.link` file in the same directory can pin
interface names to MAC addresses so a board swap does not rename them.
