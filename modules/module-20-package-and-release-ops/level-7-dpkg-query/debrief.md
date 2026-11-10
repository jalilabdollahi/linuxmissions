# Autopsy of a Failed Upgrade

## Why it works
`dpkg-query -W -f` prints exactly the fields you ask for, one line per package.
`${db:Status-Abbrev}` is the `dpkg -l` state in three letters: the second one is the
current state (`i` installed, `c` config-files left, `U` unpacked, `F` half-configured,
`H` half-installed, `t`/`W` waiting for triggers, `n` not installed). `--admindir`
points dpkg at a copied database instead of the live one, which is the safe way to
investigate a dead server's package state.

## Common mistakes
- Treating `Installed-Size` as bytes or MiB: it is **KiB**.
- `grep libs` over whole lines: it matches `libssl-dev` (section libdevel) and names
  containing "libs".
- Putting `${Section}` in the middle of a space-separated format: a package without a
  Section leaves an empty field and shifts every column after it.
- Counting `hi` (held) as broken. A hold is a choice, not damage.

## Next step
`dpkg --audit` (as root on the server) lists packages left half-installed, and
`dpkg --configure -a` finishes configuring what was unpacked.
