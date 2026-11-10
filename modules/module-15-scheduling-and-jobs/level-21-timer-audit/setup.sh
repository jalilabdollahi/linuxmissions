#!/bin/bash
# After a host migration, 4 of 11 timers never fire: a service with another
# name, an impossible OnCalendar, a misspelled section header, no [Install].
SANDBOX="$1"
cd "$SANDBOX" || exit 1
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
bash "$MOCKS/cron/install.sh" "$SANDBOX" systemd-analyze >/dev/null
U=etc/systemd/system
mkdir -p "$U" .lm

svc() {   # svc NAME DESCRIPTION EXEC [extra [Service] line]
  {
    printf '[Unit]\nDescription=%s\n\n[Service]\nType=oneshot\n' "$2"
    [ -n "$4" ] && printf '%s\n' "$4"
    printf 'ExecStart=%s\n' "$3"
  } > "$U/$1.service"
}

svc backup-nightly      "Nightly file backup"          "/usr/local/bin/backup-run --incremental" "User=backup"
svc logrotate-app       "Rotate application logs"      "/usr/sbin/logrotate /etc/logrotate.d/app"
svc certbot-renew       "Renew TLS certificates"       "/usr/bin/certbot renew --quiet"
svc db-vacuum           "Vacuum the orders database"   "/usr/local/bin/db-vacuum --analyze" "User=postgres"
svc mail-queue-flush    "Flush the outgoing mail queue" "/usr/sbin/postqueue -f"
svc report-weekly       "Weekly management report"     "/opt/reports/weekly.sh" "User=reports"
svc cache-warm          "Warm the page cache"          "/opt/app/bin/cache-warm"
svc disk-check          "Check disk usage"             "/usr/local/bin/disk-check --warn 85"
svc ntp-resync          "Resync the clock"             "/usr/sbin/hwclock --systohc"
svc sessions-purge      "Purge expired sessions"       "/opt/app/bin/sessions-purge --older-than 30d"
svc metrics-push        "Push metrics to the gateway"  "/usr/local/bin/metrics-push"

tmr() {   # tmr NAME DESCRIPTION  -- timer body (the [Timer] part) on stdin, then Install as $3
  {
    printf '[Unit]\nDescription=%s\n\n' "$2"
    cat
    [ "$3" = install ] && printf '\n[Install]\nWantedBy=timers.target\n'
  } > "$U/$1.timer"
}

tmr backup-nightly "Run the nightly backup" install <<'EOF'
[Timer]
OnCalendar=*-*-* 01:30:00
Persistent=true
EOF
tmr logrotate-app "Rotate application logs daily" install <<'EOF'
[Timer]
OnCalendar=daily
AccuracySec=1h
EOF
tmr cert-renew "Twice-daily certificate renewal check" install <<'EOF'
[Timer]
OnCalendar=*-*-* 03,15:00:00
RandomizedDelaySec=30min
EOF
tmr db-vacuum "Vacuum the orders database at night" install <<'EOF'
[Timer]
OnCalendar=*-*-* 25:00:00
Persistent=true
EOF
tmr mail-flush "Flush the mail queue regularly" install <<'EOF'
[Timer]
OnBootSec=5min
OnUnitActiveSec=10min
Unit=mail-queue-flush.service
EOF
tmr report-weekly "Weekly management report, Monday morning" install <<'EOF'
[Timers]
OnCalendar=Mon *-*-* 07:00:00
Persistent=true
EOF
tmr cache-warm "Warm the cache every quarter hour" install <<'EOF'
[Timer]
OnCalendar=*:0/15
EOF
tmr disk-check "Disk check on weekdays" install <<'EOF'
[Timer]
OnCalendar=Mon..Fri *-*-* 07:30:00
EOF
tmr ntp-resync "Resync the hardware clock hourly" install <<'EOF'
[Timer]
OnCalendar=hourly
Persistent=true
EOF
tmr sessions-purge "Purge expired sessions every night" noinstall <<'EOF'
[Timer]
OnCalendar=*-*-* 04:10:00
Persistent=true
EOF
tmr metrics-push "Push metrics every five minutes" install <<'EOF'
[Timer]
OnCalendar=*:0/5
Unit=metrics-push.service
EOF

# keep fingerprints of the seven timers that are fine
( cd "$U" && for t in backup-nightly logrotate-app mail-flush cache-warm disk-check ntp-resync metrics-push; do
    sha256sum "$t.timer" 2>/dev/null || shasum -a 256 "$t.timer"; done ) > .lm/good.sha

( cd "$U" && for s in *.service; do sha256sum "$s" 2>/dev/null || shasum -a 256 "$s"; done ) > .lm/services.sha

cat > MIGRATION.txt <<'EOF'
web-07 was rebuilt last weekend; the units in etc/systemd/system were copied over
from the old host with rsync. Since then the on-call engineer noticed that
the night-time housekeeping did not run: no cert renewal, no vacuum, no
weekly report, no session purge. `systemctl list-timers` on the old host
showed 11 timers; on the new one four of them never elapse.

Wanted:
  * broken.txt: the names of the four broken timers, one per line (e.g. foo.timer)
  * the four fixed, with the smallest change that makes each one work: a
    valid OnCalendar, an existing service to start, and enabled through
    timers.target. Timers that work must stay byte-identical, and do not
    touch the services except to rename one.
bin/systemd-analyze is a mock that supports only: systemd-analyze calendar SPEC
EOF
