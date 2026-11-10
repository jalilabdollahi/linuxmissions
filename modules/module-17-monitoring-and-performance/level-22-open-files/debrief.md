# Too Many Open Files

## Why it works
Each open descriptor is a symlink in `/proc/PID/fd/`, so `ls | wc -l` counts
them, and `/proc/PID/limits` gives the limit that applies to that very process.
The danger is the ratio: the files service holds more descriptors than anyone
but has a limit of thousands, while the API sits a few descriptors from a soft
limit of a couple of hundred. `readlink` shows what leaks: `socket:[...]`
links mean connections that are opened and never closed. The soft limit is the
enforced one; the hard limit is only how high the process may raise it.

## Common mistakes
- Ranking by raw descriptor count instead of the percentage of the limit.
- Reporting the hard limit (the second number) or the shell's `ulimit -n`
  instead of the process's own soft limit.
- Counting `/proc/PID/fdinfo` or using `lsof`'s total, which also lists memory maps.

## Next step
`prlimit --pid PID --nofile=` changes a running process's limit (root needed to
raise the hard one), `ss -p` shows which sockets belong to it, and
`ulimit -n` in a systemd unit is `LimitNOFILE=`. A raise only buys time: fix
the leak.
