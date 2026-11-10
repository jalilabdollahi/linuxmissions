# Why Does Boot Take 2.5 Minutes?

## Why it works
`systemd-analyze blame` sorts units by how long they took, but most of them run in
parallel and nobody waits for them (`snapd.seeded`, `apt-daily`). `critical-chain` shows
the units that each had to finish before the next could start, ending at the boot target:
the `+` time on that path is what the boot actually waited for. Here a wait-online
service sat for its full timeout because one network port had no cable. A vendor unit under
`/usr/lib/systemd/system` is never edited; a drop-in in `/etc/systemd/system/<unit>.d/`
overrides parts of it. For `ExecStart=` the drop-in has to clear the old value with an
empty assignment first, otherwise the old command runs as well.

## Common mistakes
- Writing the first line of `blame` into `slow_unit.txt`.
- A drop-in with only `ExecStart=new command`: the slow command still runs first.
- A drop-in file that does not end in `.conf` is silently ignored.

## Next step
`systemctl edit <unit>` creates the drop-in for you, `systemctl cat <unit>` shows the unit
with all its drop-ins merged, and `systemd-analyze critical-chain <unit>` limits the chain
to one unit. `systemd-analyze plot > boot.svg` draws the whole boot.
