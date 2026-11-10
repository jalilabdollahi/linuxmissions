#!/bin/bash
# From Cron to Timer: replace `30 2 * * 1-5 /opt/app/purge.sh` with a service
# and a timer. systemd-analyze calendar (shared mock) checks OnCalendar specs.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
bash "$MOCKS/cron/install.sh" "$SANDBOX" systemd-analyze >/dev/null
mkdir -p etc/systemd/system

cat > crontab.txt <<'CRON'
# app server, user app -- being migrated to systemd timers (see MIGRATION.txt)
MAILTO=ops@example.com
# m  h  dom mon dow  command
# 30 2  *   *   1-5  /opt/app/purge.sh          <- next to migrate
30 2 * * 1-5 /opt/app/purge.sh
*/10 * * * * /opt/app/heartbeat.sh
CRON

cat > MIGRATION.txt <<'TXT'
Cron -> systemd timers
----------------------
For each job: a .service that runs the command once, and a .timer that starts it.
Units live in /etc/systemd/system (here: etc/systemd/system). Done so far:
  - stats-export   (see stats-export.service / stats-export.timer)
Requirements for every new timer:
  * same schedule as the cron line it replaces
  * a run missed while the box was off happens at the next boot
  * enabled like every other timer (systemctl enable purge.timer must work)
TXT

cat > etc/systemd/system/stats-export.service <<'UNIT'
[Unit]
Description=Export usage statistics to the warehouse

[Service]
Type=oneshot
User=app
ExecStart=/opt/app/stats-export.sh --since yesterday
UNIT
cat > etc/systemd/system/stats-export.timer <<'UNIT'
[Unit]
Description=Export usage statistics every night

[Timer]
OnCalendar=*-*-* 01:15:00
RandomizedDelaySec=10min

[Install]
WantedBy=timers.target
UNIT
