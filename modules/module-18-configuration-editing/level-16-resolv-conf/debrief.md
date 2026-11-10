# Resolver That Remembers

## Why it works
On a systemd-resolved host `/etc/resolv.conf` is a symlink to a file the service regenerates
(the "DO NOT EDIT" header says so), so a hand edit lasts only until the next restart. The
persistent place for local settings is a drop-in in `resolved.conf.d/`, which leaves the
package's own file alone and survives upgrades. `DNS=` and `Domains=` are lists that accumulate
across files, which is why the old server and domain stayed until the new drop-in reset them
with an empty assignment.

## Common mistakes
- `sed -i` on etc/resolv.conf: it replaces the symlink with a regular file, and systemd-resolved no longer owns it.
- Adding `DNS=` without resetting it: the vendor's old server stays in the list.
- Editing the packaged resolved.conf: the next package update asks about it or overwrites it.

## Next step
`systemctl cat unit`, `systemd-analyze cat-config systemd/resolved.conf` and `resolvectl status` show the merged
result of base file and drop-ins on a real system.
