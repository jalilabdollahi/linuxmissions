# Five Seconds per Name

## Why it works
The stub resolver in glibc does exactly what resolv.conf says, and the
query logs showed every step. Each query went to the switched-off server
first and waited `timeout` seconds before the second server got it. For
`api` (0 dots, fewer than ndots) it walked the search list in order and
only the *last* domain had the name, so one lookup cost three queries and
three timeouts. With `ndots:5`, even `db.corp.example` (2 dots) was first
glued to every search domain (`db.corp.example.corp.example`, ...). The
fixed file lists only the live server, puts the service domain first, and
uses the default ndots of 1, so names with a dot are tried as they are.

## Common mistakes
- Removing the search domains to make full names fast: short names stop
  resolving.
- Testing with `dig`/`host`: they don't use the search list unless asked
  (`dig +search`), so they never show the slow path.
- Keeping the dead server "as a backup": a nameserver that never answers
  isn't a backup, it's a timeout on every failover.

## Learn next
Kubernetes pods get `ndots:5` and a long search list by default, which is
why "api" lookups inside a cluster cause many queries; writing names with a
trailing dot (`api.svc.corp.example.`) skips the search list completely.
On systemd-resolved hosts, `resolvectl query api` and `resolvectl status`
show the same decisions, and `options edns0 trust-ad` / `rotate` are worth
reading about in `man resolv.conf`.
