#!/bin/bash
# Decommission legacy-sync: a packaged (vendor) unit in /usr/lib/systemd/system,
# enabled and running. report.service, which must stay, has
# Wants=legacy-sync.service, so after a plain `disable` the next boot (or the
# next start of report) brings legacy-sync back. Only `mask` (a link to
# /dev/null in /etc/systemd/system) stops that. The vendor file is in
# usr/lib, so mask works as on a real system.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
M="$(dirname "$0")/../../../mocks"

mkdir -p bin etc/systemd/system usr/lib/systemd/system opt/legacy-sync/bin opt/reports/bin \
         var/spool/legacy-sync var/lib/reports .lm-state
cp "$M/systemd/systemctl" "$M/systemd/journalctl" bin/
echo files-01 > etc/hostname
ln -s /usr/lib/systemd/system/multi-user.target etc/systemd/system/default.target

cat > opt/legacy-sync/bin/legacy-sync <<'EOF'
#!/bin/bash
# legacy-sync 0.9.3 (deprecated): mirror /srv/share to the old NAS every 30s
echo "legacy-sync 0.9.3 started: /srv/share -> nas-old.corp:/vol/share (rsync)"
while :; do
  date +%s > var/spool/legacy-sync/last-run 2>/dev/null
  echo "sync pass done: $((RANDOM % 40)) files changed"
  sleep 30
done
EOF
cat > opt/reports/bin/report-server <<'EOF'
#!/bin/bash
echo "report-server 2.3 listening on 127.0.0.1:8090"
while :; do sleep 120; echo "rendered $((RANDOM % 12)) scheduled reports"; done
EOF
cat > opt/reports/bin/report-archiver <<'EOF'
#!/bin/bash
echo "report-archiver watching /var/lib/reports"
while :; do sleep 300; echo "archived 0 reports"; done
EOF
chmod +x opt/legacy-sync/bin/legacy-sync opt/reports/bin/*

# Shipped by the legacy-sync package.
cat > usr/lib/systemd/system/legacy-sync.service <<'EOF'
[Unit]
Description=Legacy share sync to nas-old
Documentation=man:legacy-sync(8)
After=network-online.target remote-fs.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/opt/legacy-sync/bin/legacy-sync
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

# Ours: the report server still reads the share the sync used to fill.
cat > etc/systemd/system/report.service <<'EOF'
[Unit]
Description=Report server
After=network-online.target legacy-sync.service
Wants=network-online.target legacy-sync.service

[Service]
Type=simple
ExecStart=/opt/reports/bin/report-server
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
cat > etc/systemd/system/report-archiver.service <<'EOF'
[Unit]
Description=Report archiver
After=report.service
PartOf=report.service

[Service]
ExecStart=/opt/reports/bin/report-archiver

[Install]
WantedBy=multi-user.target
EOF

./bin/systemctl enable legacy-sync.service report.service report-archiver.service >/dev/null 2>&1
./bin/systemctl mock-boot >/dev/null 2>&1

# Reference copies: the vendor unit and report.service must stay as they are.
cksum usr/lib/systemd/system/legacy-sync.service etc/systemd/system/report.service > .lm-state/units.sum
exit 0
