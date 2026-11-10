# Too Many Open Files

## Why it works
Each process has resource limits (`/proc/PID/limits`) and a table of open
descriptors (`/proc/PID/fd`); comparing the two shows how close it is to the
wall. The soft limit is the one enforced, the hard limit is the ceiling the
process may raise it to. For services started by systemd, limits come from the
unit: `LimitNOFILE=` in the unit file or in a drop-in in `unit.service.d/`.
Drop-ins are read in name order, so the last `LimitNOFILE=` wins, which is why
the old `10-legacy.conf` had to be outranked.

## Common mistakes
- Editing `/etc/security/limits.conf`: only PAM sessions (logins, `su`, sshd)
  read it, a systemd service does not.
- Putting `LimitNOFILE=` under `[Unit]` or `[Install]`, where it is ignored.
- Naming the drop-in so that it sorts before another one that also sets it.
- Forgetting that the running process keeps its old limit until restarted
  (`systemctl daemon-reload` and a restart on the real host).

## Next step
`prlimit --pid PID --nofile=SOFT:HARD` changes limits of a running process
(root), and `systemctl show indexer -p LimitNOFILE` prints the value systemd
will apply. `systemctl edit indexer` creates the drop-in for you.
