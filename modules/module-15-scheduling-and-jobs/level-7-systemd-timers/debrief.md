# From Cron to Timer

## Why it works
A systemd timer is two units. `purge.service` (Type=oneshot) is the job; `purge.timer`
starts the service with the same name (or the one in `Unit=`) whenever `OnCalendar=`
elapses. `Mon..Fri *-*-* 02:30:00` is cron's `30 2 * * 1-5`. With `Persistent=true`
systemd records the last run in `/var/lib/systemd/timers/` and, at boot, starts a run that
was missed while the machine was off. Cron simply skips those. `WantedBy=timers.target`
is what `systemctl enable --now purge.timer` hooks the timer into.

## Common mistakes
- `OnCalendar=daily` is `*-*-* 00:00:00`: wrong time and every day, weekends included.
- Naming the timer `purge-nightly.timer` without `Unit=purge.service`: it looks for
  `purge-nightly.service`, which doesn't exist.
- `WantedBy=multi-user.target` on a timer: it works at boot, but it is not the convention,
  and `systemctl list-timers` users expect timers.target.

## Next step
On a real server: `systemctl daemon-reload`, `systemctl enable --now purge.timer`, then
`systemctl list-timers purge.timer` shows the next and last run, and
`journalctl -u purge.service` the output. `RandomizedDelaySec=` spreads load across a fleet.
