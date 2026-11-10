# Wrong Database

## Why it works
systemd builds a service's environment in a fixed order: `Environment=`
lines first, then every `EnvironmentFile=` in the order they appear, and a
later assignment of the same variable wins. Here the site file
`/etc/billing/env` was meant to come last, after the vendor defaults, but its
path had a typo. The leading `-` in `EnvironmentFile=-/etc/biling/env`
means "optional", so systemd skipped the missing file without a word.

The second problem was the file's syntax. Env files are not shell scripts:
`#` starts a comment only at the start of a line, so
`DB_PORT=6432   # via pgbouncer` hands the program the value
`6432   # via pgbouncer`.

## Common mistakes
- Changing `Environment=DB_HOST=...` in the unit: a value from an
  EnvironmentFile still overrides it, so nothing changes.
- Editing the vendor defaults in /etc/default/billing: it works until the
  next package upgrade overwrites the file.
- Forgetting `daemon-reload` after editing the unit, or the restart after
  editing the env file.

## Next step
`systemctl show -p Environment` only lists what the unit sets itself. To see
what the process really got, read `/proc/<MainPID>/environ`
(`tr '\0' '\n' < /proc/PID/environ`). Drop the `-` from an EnvironmentFile=
that must exist, and systemd refuses to start with a clear error instead.
