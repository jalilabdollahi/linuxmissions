# Survive the Hangup

## Why it works
When a terminal (or an SSH/VPN connection) goes away, the kernel and the shell send
**SIGHUP** to the jobs of that session, and a process that hasn't changed the default dies.
`nohup` sets SIGHUP to "ignore" and then runs the command. An ignored signal stays ignored
across `exec`, so migrate.sh inherited it. You can see it in `/proc/PID/status` as bit 1 of
`SigIgn`. The redirections you gave sent its output to `logs/migrate.log`. nohup only
invents `nohup.out` when stdout is still a terminal.

## Common mistakes
- `./migrate.sh &` alone: it is in the background but still dies on hangup.
- `nohup ./migrate.sh &`: the output lands in `nohup.out` (or `~/nohup.out`), where nobody
  looks for it.
- Redirection order: `cmd 2>&1 > log` points stderr at the *old* stdout (the terminal)
  first and only then stdout at the log. nohup happens to rescue you (it sends a terminal
  stderr to stdout), but in every other command the order is `> log 2>&1`.

## Next step
`disown -h %1` marks a job that is already running so bash won't pass SIGHUP to it, but
the process itself doesn't ignore the signal. `setsid` (next levels) detaches completely.
For really long jobs on servers, `tmux`/`screen` or a systemd unit
(`systemd-run --user --unit migrate ./migrate.sh`) are better tools.
