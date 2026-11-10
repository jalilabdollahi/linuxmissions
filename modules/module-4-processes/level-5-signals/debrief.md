# Signal Relay

## Why it works
`kill` doesn't only kill: it sends any **signal** to a process. A program can
catch most signals and decide what to do; `listener.sh` does it with
`trap load_config HUP`. By convention, daemons such as nginx, sshd and rsyslog
reload their configuration on **SIGHUP**, so `kill -HUP $(cat listener.pid)` applies
the new setting while clients stay connected and the PID stays the same.

| Signal | Typical meaning |
|--------|-----------------|
| SIGHUP (1)  | reload config / reopen log files |
| SIGTERM (15)| please shut down cleanly |
| SIGKILL (9) | die now (can't be caught) |
| SIGUSR1/2   | program-specific (e.g. dd prints progress on USR1) |

## Common mistakes
- Editing the config and expecting it to take effect: most programs read it
  only at start or on reload.
- Sending HUP to a program that doesn't handle it: the default action for SIGHUP
  is to *terminate*. Check the docs first.

## Learn next
`systemctl reload nginx` does the same for a systemd service (it usually sends
SIGHUP for you), and `nginx -t` / `sshd -t` test a config before you reload it.
