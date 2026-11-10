# The Driver That Never Loads

## Why it works
`modprobe` builds its behaviour from every `*.conf` file under `/etc/modprobe.d/`. Three
directives touch ixgbe here, and only one blocks it. `blacklist` only stops *alias*
expansion (a PCI device asking for its driver), not `modprobe ixgbe` by name.
`options` just adds module parameters. `install ixgbe /bin/true` replaces the whole load
with a command that does nothing and succeeds, so the module never arrives and no error
shows. Commenting out that one line is the smallest correct fix. The `.disabled` file is
ignored because modprobe only reads names ending in `.conf`.

## Common mistakes
- Removing the `blacklist` line and wondering why nothing changed.
- Deleting the whole workaround file and losing the `options` line the NIC needs.
- Editing the `.disabled` file: it never took effect.

## Next step
`modprobe -c` prints the merged configuration, `modprobe -n -v NAME` shows the chain, and
`modprobe --ignore-install NAME` bypasses an install rule for one run.
`modinfo -F depends NAME` lists direct dependencies.
