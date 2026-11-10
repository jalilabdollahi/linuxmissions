# What's Listening?

## Why it works
A `LISTEN` socket is a service waiting for connections; its local address
decides who may connect. `0.0.0.0` (all IPv4 addresses), `[::]` (all IPv6),
`*` (both) and the host's own address 10.20.4.17 are reachable from the
network, while `127.0.0.1`, `127.0.0.53%lo` and `[::1]` only accept
connections from the machine itself. Splitting at `:` and taking the last
piece gets the port even from IPv6 addresses that contain colons themselves.

## Common mistakes
- Counting `ESTAB` rows: their local port is either a service port already
  covered by a LISTEN row, or a random outgoing port like 35870.
- Reporting PostgreSQL (5432) and Redis (6379) as exposed. They are bound to
  127.0.0.1, which is exactly how such services should be set up.
- Remember that a listening port can still be blocked by a firewall: ss shows
  what the host *offers*, not what the network lets through.

## Learn next
`ss -tlnp` (run as root) adds the Process column with the program and PID
behind each port, and `ss -tln 'sport = :443'` filters inside ss itself.
`sudo lsof -iTCP -sTCP:LISTEN -P -n` gives the same view per process.
