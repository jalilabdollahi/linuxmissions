# Restart Storm

## Why it works
`Restart=` decides which exits trigger a restart, `RestartSec=` how long
systemd waits before it tries again, and `StartLimitBurst=` /
`StartLimitIntervalSec=` how many starts it allows inside a time window
before it gives up with `start-limit-hit`. The default is 5 starts in 10
seconds with a pause of only 100 ms, so a service that fails instantly runs
out of attempts in half a second, long before a broker comes back. A pause of a few
seconds and a bigger burst stretch the same number of attempts over minutes.
`Restart=on-failure` leaves a deliberate exit 0, such as an operator's
drain, alone.

## Common mistakes
- `Restart=always`: it fixes the crashes, and it also resurrects a service
  someone stopped on purpose by letting it exit.
- Putting `StartLimitIntervalSec=` in `[Service]` or forgetting
  `daemon-reload`, then wondering why `systemctl show` still prints the old
  values.
- Only raising `StartLimitBurst` and leaving the 100 ms pause: the attempts are
  still gone before the broker is back.

## Next step
`systemctl show -p NRestarts UNIT` counts the automatic restarts.
`SuccessExitStatus=` and `RestartPreventExitStatus=` fine-tune which exit
codes count as success or never restart.
