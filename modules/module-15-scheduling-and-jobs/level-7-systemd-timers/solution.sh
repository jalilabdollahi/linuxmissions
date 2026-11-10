#!/bin/bash
cat > etc/systemd/system/purge.service <<'UNIT'
[Unit]
Description=Purge expired app data

[Service]
Type=oneshot
ExecStart=/opt/app/purge.sh
UNIT
cat > etc/systemd/system/purge.timer <<'UNIT'
[Unit]
Description=Purge expired app data on weekdays at 02:30

[Timer]
OnCalendar=Mon..Fri *-*-* 02:30:00
Persistent=true

[Install]
WantedBy=timers.target
UNIT
bin/systemd-analyze calendar --iterations=3 'Mon..Fri *-*-* 02:30:00'
