#!/bin/bash
# app.service writes var/log/app/app.log and audit.log through file
# descriptors it opens once at start. etc/logrotate.d/app rotates them with
# `create` and nothing else: logrotate renames the files and creates new empty
# ones, but the app keeps writing into the renamed app.log.1/audit.log.1
# (same inode), and the new files stay empty. The app reopens its logs on
# SIGHUP (ExecReload= in the unit). Setup starts the app and runs last
# night's rotation with the broken config, so the app is already writing
# into the .1 files. The fix: postrotate + reload, with sharedscripts so the
# app gets one reload per rotation, not one per log file.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
M="$(dirname "$0")/../../../mocks"

mkdir -p bin etc/systemd/system etc/logrotate.d opt/app/bin var/log/app var/lib/app .lm-state
cp "$M/systemd/systemctl" "$M/systemd/journalctl" bin/
echo app-05 > etc/hostname

cat > opt/app/README <<'EOF'
app 3.1 - order intake service
Logs:    /var/log/app/app.log (requests), /var/log/app/audit.log (audit trail)
Signals: SIGHUP closes and reopens both log files (for log rotation).
         SIGTERM shuts down.
The audit trail must be complete: copying and truncating a log under the
running app (logrotate's copytruncate) can lose lines and is not allowed.
EOF

cat > opt/app/bin/app <<'EOF'
#!/bin/bash
# app 3.1 (simplified): one request line and one audit line every half second.
D=var/log/app
open_logs() { exec 3>>"$D/app.log" 4>>"$D/audit.log"; }
stamp() { date '+%Y-%m-%dT%H:%M:%S%z'; }
on_hup() {
  echo $(( $(cat var/lib/app/hup-count 2>/dev/null || echo 0) + 1 )) > var/lib/app/hup-count
  open_logs
  echo "$(stamp) INFO SIGHUP: reopened $D/app.log and $D/audit.log" >&3
}
open_logs
trap on_hup HUP
echo "$(stamp) INFO app 3.1 started, pid $$" >&3
i=0
while :; do
  i=$((i + 1))
  echo "$(stamp) INFO POST /orders 201 order=$((700000 + i)) $((20 + RANDOM % 200))ms" >&3
  echo "$(stamp) AUDIT order=$((700000 + i)) user=u$((1000 + RANDOM % 9000)) action=create" >&4
  sleep 0.5 & wait $!
  kill $! 2>/dev/null
done
EOF
chmod +x opt/app/bin/app

cat > etc/systemd/system/app.service <<'EOF'
[Unit]
Description=Order intake app
After=network-online.target

[Service]
Type=simple
ExecStart=/opt/app/bin/app
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Written by a colleague; logrotate runs it from cron every night.
cat > etc/logrotate.d/app <<EOF
# rotate the app's logs nightly
$SANDBOX/var/log/app/*.log {
    daily
    rotate 7
    missingok
    compress
    delaycompress
    create 0640
}
EOF

echo 0 > var/lib/app/hup-count
./bin/systemctl enable --now app.service >/dev/null 2>&1
sleep 2
# Last night's rotation with that config.
logrotate -s .lm-state/nightly.state -f etc/logrotate.d/app
sleep 1
