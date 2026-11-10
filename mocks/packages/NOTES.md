# mocks/packages: additions (module 20 run)

To be merged into the "packages/" section of `mocks/README.md`.

## Several suites in one mirror directory

Repositories whose `path` is the same directory are built into it together: the first one
clears `dists/` and `pool/`, the others add their `dists/<suite>/` and pool files. This is
how a real mirror looks (`noble`, `noble-updates`, `noble-security` under one URI), and it
lets one deb822 stanza or one-line URI list several suites. Previously a second repository
with the same `path` deleted the first one's files. Give each suite its own `name` (the
default sources file name derives from it; use `"sources": "none"` and write the sources by
hand when one file should describe them all).

```json
{"repos": [
  {"name": "noble",         "suite": "noble",         "path": "repos/ubuntu", "sources": "none", "packages": [...]},
  {"name": "noble-updates", "suite": "noble-updates", "codename": "noble", "path": "repos/ubuntu", "sources": "none", "packages": [...]}]}
```

## Recipes used by module 20 (no code changes, nothing new to learn)

- Hand-built `dpkg` status file for `dpkg-query --admindir=DIR` (level 7): the real
  dpkg-query reads `DIR/status` alone. Entries with state `triggers-pending` /
  `triggers-awaited` need a `Triggers-Pending:` / `Triggers-Awaited:` field or dpkg refuses the file.
- Held packages show up in the "kept back" paragraph of `apt-get -s upgrade`, so a level that
  asks for kept-back names must not hold anything.
- apt does not downgrade an installed dependency by itself: `apt install fluxd=3.1.4-1` fails
  with "Depends: libflux1 (< 1.5) but 1.5.0-1 is to be installed" until `libflux1=1.4.2-1` is on the
  command line too.
- `dpkg -S /bin/x` finds nothing on a usrmerge root when the package lists `/usr/bin/x`.
- `apt-cache policy PKG` shows URL and suite per version; the `o=`/`a=`/`n=` release line is only
  printed by plain `apt-cache policy`.
- A file that is not named `*.pref` (or has no extension) in `preferences.d/` is ignored by apt.
