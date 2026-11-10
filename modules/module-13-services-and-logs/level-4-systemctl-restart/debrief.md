# Reload, Don't Restart

## Why it works
- `systemctl restart` stops the main process (SIGTERM) and starts a new one, so you get
  a new PID and every job in memory is lost.
- `systemctl reload` runs the unit's `ExecReload=` command instead. For most daemons
  that means sending SIGHUP to the main process (`/bin/kill -HUP $MAINPID`). The process
  re-reads its config and keeps running with the same PID.
- Without `ExecReload=`, systemd has no idea how to reload the service and says "Job type
  reload is not applicable".

Two different reloads were needed here:
- `systemctl daemon-reload` makes **systemd** re-read unit files. It's how the new
  `ExecReload=` line became known. It does nothing to the api.
- `systemctl reload api` makes the **api** re-read *its* config.

## Common mistakes
- `reload-or-restart`: it reloads when the unit supports it and restarts otherwise.
  Before the fix it restarted.
- Thinking `daemon-reload` applies an app's config change. It only concerns unit files.
- Assuming every program reloads on SIGHUP. Some exit on it. Check the docs.

## Next step
`systemctl show -p ExecMainStartTimestamp,MainPID api` proves a process wasn't
restarted. Many packaged units ship `ExecReload=` already (nginx, sshd, rsyslog), and
`nginx -t && systemctl reload nginx` is the classic safe way to apply a web server config.
