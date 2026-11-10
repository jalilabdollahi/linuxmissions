# Connection Map

## Why it works
Three filters turn 385 sockets into the answer: the state (`ESTAB` only, since
`TIME-WAIT` and `CLOSE-WAIT` sockets are connections that are already closing),
the local side (`:443` in column 4, which excludes the 48 connections web-03
opened to its own database), and cutting the peer port with `sub(/:[0-9]+$/,
"")` so all connections from one client become identical lines. Then
`sort | uniq -c | sort -nr` is the classic "count and rank" pipeline.

## Common mistakes
- Splitting the peer at the first `:`. That works for IPv4, but turns the IPv6
  client `[2001:db8:77::5]:51234` into `[2001`.
- Counting every row for an address: 198.51.100.23 has 55 sockets, but 25 of
  them are TIME-WAIT leftovers from connections that already ended.

## Learn next
`ss` can filter by itself: `ss -tn state established '( sport = :443 )'`
lists only established HTTPS connections, and `ss -s` prints a summary of
socket counts per state. `conntrack -L` shows the same picture from the
firewall's connection table.
