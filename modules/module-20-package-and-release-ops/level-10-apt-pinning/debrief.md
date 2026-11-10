# One Package From Backports

## Why it works
apt chooses the version with the highest priority. The main archive is 500; a
`NotAutomatic: yes` repository such as backports is 100, so its packages are never picked
unless asked for. A pin with `Package: ripgrep`, `Pin: release a=noble-backports` and
`Pin-Priority: 600` raises only that package's backports version above 500, so apt offers it
and everything else is untouched. The release field matters: `a=` is the **Suite** in the
repository's Release file (`noble-backports`); `n=` is the **Codename**, `noble`, which main
shares, so `n=noble-backports` matches nothing.

## Common mistakes
- `Package: *` with a pin on the backports release: every backported package is offered.
- A file named `ripgrep.conf` or `ripgrep.pref.txt`: apt ignores it silently.
- Priority 500 or lower: no better than main, and the version tie-break is easy to get wrong.

## Next step
`apt install -t noble-backports ripgrep` takes one package from backports for one command
without writing a pin, and `apt-cache policy` shows the priority of every repository.
