# From tmux to systemd

## Why it works
A unit file answers three questions. `[Unit]` says what the service is and
what it should start after, `[Service]` says how to run it, and `[Install]`
says which target pulls it in when `systemctl enable` is run. systemd starts
`ExecStart=` directly, not through a shell, so the path must be absolute
and the old `cd` becomes `WorkingDirectory=`. With `Type=simple` systemd
treats the process it started as the service itself, so a program that
detaches into the background and exits (what the script does without
`--foreground`) looks to systemd like a service that finished, and it
cleans up whatever is left.

## Common mistakes
- A relative `ExecStart=./bin/report-api`: rejected by systemd.
- Leaving out `WorkingDirectory=`: the program starts in `/` and cannot find
  its config file.
- Keeping the trailing `&` or no `--foreground`: the service looks dead one
  second after `start` even though a stray process may seem to run for a moment.
- Forgetting `daemon-reload` after writing the file, or `enable`: it works now
  and is gone after the next reboot.

## Next step
`Type=forking` with `PIDFile=` is the way to supervise a program that really
cannot stay in the foreground. `systemctl cat` and `systemd-analyze verify`
are the first things to run on a unit that will not start.
