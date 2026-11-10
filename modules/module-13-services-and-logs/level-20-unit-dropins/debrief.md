# Hands Off the Vendor Unit

## Why it works
systemd builds a unit from its main file plus every `*.conf` in
`<unit>.d/` directories, read in name order, with `/etc` taking priority
over `/usr/lib`. Your drop-in lives in `/etc`, so a package upgrade can
replace the vendor's file without erasing your changes. Settings that are
lists (`Environment=`) simply gain entries. `ExecStart=` is also a list, but a
`Type=simple` service may have only one command, so you first assign it an
empty value, which clears what came before, and then give your own.

## Common mistakes
- Editing the file in `usr/lib/systemd/system`: it is gone after the next
  upgrade.
- Copying the whole unit to `/etc/systemd/system/`: it works, but it hides
  the vendor's file for good, including every future fix to it.
- A second `ExecStart=` without the empty line before it: the unit is
  rejected and will not start at all.
- No `daemon-reload`, or no restart: systemd and the process keep the old
  settings.

## Next step
`systemctl edit UNIT` creates the drop-in for you (not available in this lab's mock),
and `systemctl revert UNIT` removes your overrides again.
`systemd-delta` lists every unit that is overridden or extended.
