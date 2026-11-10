# Who Gave That Root?

## Why it works
A setuid program runs with its owner's rights (usually root), a setgid program with its
group's. Every one is a door into a privileged account, so a baseline of the expected doors
is a standard audit tool. `find -perm /6000` finds any file with either bit, and
`grep -vxFf baseline found` keeps only what the baseline does not list (`-F` fixed strings,
`-x` whole lines, `-f` patterns from a file, `-v` invert). `chmod u-s,g-s` turns the bits
off and leaves read/write/execute alone.

Both traps are real: attackers drop a copy of a shell (`.cache-helper`) with setuid in a
dot-directory because nobody looks there, and a baseline entry only describes a *path*:
`/usr/local/bin/pkexec` is not `/usr/bin/pkexec`, so it counts as unexpected.

## Common mistakes
- `ls /usr/bin`-style checks: they miss hidden directories and unusual locations.
- `chmod 755` on the findings: it also changes the other bits (an `0711` helper would
  suddenly become world-readable).
- Forgetting the comment lines in the baseline when comparing.

## Next step
`find / -xdev -perm /6000 -type f 2>/dev/null` is the whole-system version; mounting
data partitions with `nosuid` stops the bits from working at all.
