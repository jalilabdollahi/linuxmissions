# Something Is Down

## Why it works
`systemctl status` tells you three different things on three lines:
- **Loaded:** where the unit file is and whether it is enabled.
- **Active:** the state, such as `active (running)`, `inactive (dead)`, `failed`, or here
  `activating (auto-restart)`. That one means the main process died and systemd is
  waiting `RestartSec=` before trying again.
- **Main PID:** the last main process. `(code=exited, status=N)` is its exit
  status, the same number as `systemctl show -P ExecMainStatus`.

The broken unit has `Restart=on-failure` and no start limit (`StartLimitIntervalSec=0`),
so it never gives up and never becomes `failed`. That is why `systemctl --failed` was
empty while the pager was right. `nightly-export.service` is `Type=oneshot`: it runs,
exits 0 and goes back to `inactive (dead)`. For a oneshot that is the healthy state.

## Common mistakes
- Trusting `systemctl --failed` or the `Failed: 0 units` line of `systemctl status`.
  A unit in a restart loop is "activating", not "failed".
- Reporting every unit that isn't running. Check `Type=` and the exit status first:
  status 0 means it finished its work.

## Next step
`journalctl -u UNIT -n 20` shows what the process printed before it exited, and
`systemctl show -P NRestarts UNIT` tells you how many times systemd has restarted it.
Exit statuses 64-78 follow `sysexits.h`. For example, 78 is EX_CONFIG, a configuration error.
