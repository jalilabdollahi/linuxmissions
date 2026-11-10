#!/bin/bash
# A deploy pushed a new api.conf (random revision) while api.service runs
# long jobs. The api re-reads its config on SIGHUP without dropping jobs
# (README), but the unit has no ExecReload=, so `systemctl reload api` says
# "Job type reload is not applicable" and reload-or-restart quietly restarts.
# The player adds ExecReload=, runs daemon-reload (systemd's own config) and
# then reload (the service's config). The Main PID at setup is recorded:
# any restart changes it.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
M="$(dirname "$0")/../../../mocks"

mkdir -p bin etc/systemd/system/multi-user.target.wants etc/api opt/api/bin var/log/api var/lib/api/jobs .lm-state
cp "$M/systemd/systemctl" "$M/systemd/journalctl" bin/
echo api-03 > etc/hostname
ln -s /usr/lib/systemd/system/multi-user.target etc/systemd/system/default.target

hex() { od -An -N2 -tx1 /dev/urandom | tr -d ' \n'; }
OLD_REV="2026.11.03-$(hex)"
NEW_REV="2026.11.10-$(hex)"

cat > opt/api/README <<'EOF'
api-server 5.4
==============
Config: /etc/api/api.conf (key = value). Log: /var/log/api/api.log

Signals
  SIGHUP   re-read /etc/api/api.conf. Running jobs keep running; new jobs use
           the new settings. This is the supported way to apply config changes.
  SIGTERM  shut down. Running jobs are ABORTED and have to be resubmitted.

Jobs are long exports (10-90 minutes). Avoid restarts during business hours.
EOF

cat > opt/api/bin/api-server <<'EOF'
#!/bin/bash
# api-server 5.4 (simplified): long-running export jobs, config re-read on HUP.
CONF=etc/api/api.conf
LOG=var/log/api/api.log
log() { echo "$(date '+%Y-%m-%dT%H:%M:%S%z') api-server[$$]: $*" >> "$LOG"; }
load() {
  rev=$(sed -n 's/^revision[[:space:]]*=[[:space:]]*//p' "$CONF")
  workers=$(sed -n 's/^workers[[:space:]]*=[[:space:]]*//p' "$CONF")
  log "config revision $rev loaded (workers=$workers)"
}
jobs_running() { ls var/lib/api/jobs | tr '\n' ' '; }
trap 'log "SIGHUP: re-reading /etc/api/api.conf, $(ls var/lib/api/jobs | wc -l) jobs keep running"; load' HUP
trap 'log "SIGTERM: shutting down, ABORTING jobs: $(jobs_running)"; rm -f var/lib/api/jobs/*; exit 0' TERM
log "api-server 5.4 starting"
load
for j in 48213 48217 48230; do touch "var/lib/api/jobs/$j"; log "job $j started (export, eta $((20 + RANDOM % 60))m)"; done
echo "api-server ready on 127.0.0.1:8070"
n=0
while :; do
  sleep 5 & wait $!
  kill $! 2>/dev/null
  n=$((n + 1))
  [ $((n % 6)) -eq 0 ] && for j in $(ls var/lib/api/jobs); do log "job $j progress $(( (n / 6 * 3 + j % 7) % 100 ))%"; done
done
EOF
chmod +x opt/api/bin/api-server

cat > etc/systemd/system/api.service <<'EOF'
[Unit]
Description=Export API server
Documentation=file:///opt/api/README
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=api
ExecStart=/opt/api/bin/api-server
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

cat > etc/api/api.conf <<EOF
# api-server configuration
revision = $OLD_REV
workers = 8
export_dir = /var/lib/api/exports
upstream_timeout = 30s
EOF

./bin/systemctl enable --now api.service >/dev/null 2>&1
for _ in 1 2 3 4 5 6 7 8 9 10; do
  grep -q "config revision $OLD_REV loaded" var/log/api/api.log 2>/dev/null && break
  sleep 0.2
done
./bin/systemctl show -P MainPID api.service > .lm-state/api.pid

# The deploy job just rewrote the config.
cat > etc/api/api.conf <<EOF
# api-server configuration
# deployed by ci-runner-2, change CHG-$(( 3000 + RANDOM % 900 )): more workers, longer timeout
revision = $NEW_REV
workers = 16
export_dir = /var/lib/api/exports
upstream_timeout = 60s
EOF
exit 0
