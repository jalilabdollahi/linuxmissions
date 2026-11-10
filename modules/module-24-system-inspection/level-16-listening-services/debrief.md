# Port to Unit Inventory

## Why it works
A process's cgroup path is how systemd keeps track of which unit it belongs
to, so the last component of `/proc/PID/cgroup` names the unit (`.service` or a
`.scope` for login sessions). Socket-activated units are different: systemd
itself (PID 1) holds the listening socket until the first connection, so
`ss` shows `systemd` as the owner. The mapping lives in the `.socket` unit's
`ListenStream=` line, and the unit it starts is the `Service=` value or the
same-named `.service`.

## Common mistakes
- Taking the first `.service` in the cgroup path: for a user's process that
  is `user@1000.service`, the manager, not the program.
- Listing `systemd` as the unit for socket-activated ports.
- Counting IPv4 and IPv6 listeners as two ports, or sorting `9090` after `80`
  as text instead of as numbers.
- Adding `.socket` units that are not listening on this host.

## Next step
On a live host `systemctl list-sockets` and `systemd-cgls` show the same
mapping, and `systemctl status PID` resolves a PID to its unit.
