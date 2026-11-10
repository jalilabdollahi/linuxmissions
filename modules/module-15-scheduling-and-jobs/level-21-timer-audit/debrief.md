# Four Silent Timers

## Why it works
A timer only fires if three things line up: the `.timer` file is valid, it starts a unit that
exists, and it is enabled. Each broken timer broke a different link. `[Timers]` is not a
section systemd knows, so it ignores the whole block and the timer has no schedule.
`OnCalendar=*-*-* 25:00:00` does not parse (there is no hour 25), so the unit fails to load;
`systemd-analyze calendar` tells you so before you reload anything. `cert-renew.timer` starts
`cert-renew.service` by default, and the service had been copied under another name:
either rename it or add `Unit=certbot-renew.service`. And `sessions-purge.timer` had no
`[Install]` section, so it could not be enabled and never started after boot.
The decoys are on purpose: `mail-flush.timer` uses `OnBootSec=`/`OnUnitActiveSec=` instead of a
calendar, and names its service with `Unit=`; both are fine.

## Common mistakes
- "Fixing" a monotonic timer by adding `OnCalendar=`: it was never broken.
- Editing the service file instead of the timer when the cause is a name mismatch.
- Fixing the file and forgetting `systemctl daemon-reload` and `systemctl enable --now` on a real host.

## Next step
On a live system `systemctl list-timers --all` shows a timer's next and last run, and
`systemd-analyze verify /etc/systemd/system/*.timer` finds unknown sections and missing units.
