#!/bin/bash
# After the reboot drill metrics-agent did not come back, although
# `systemctl is-enabled` says "enabled". Its unit was copied from a desktop
# template: [Install] WantedBy=graphical.target, so `enable` linked it into
# graphical.target.wants. This server boots into multi-user.target, which
# never pulls in graphical.target, so the link is never followed. The setup
# enables everything and then runs the mock's simulated boot (the drill),
# which starts the other services and leaves metrics-agent stopped.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
M="$(dirname "$0")/../../../mocks"

mkdir -p bin etc/systemd/system opt/metrics-agent/bin opt/shop/bin etc/metrics-agent
cp "$M/systemd/systemctl" "$M/systemd/journalctl" bin/
echo mon-07 > etc/hostname
ln -s /usr/lib/systemd/system/multi-user.target etc/systemd/system/default.target

cat > etc/metrics-agent/agent.yaml <<'EOF'
# metrics-agent: scrape local exporters, push to the central gateway
push_gateway: http://10.0.5.9:9091
interval: 15s
targets:
  - 127.0.0.1:9100   # node
  - 127.0.0.1:9187   # postgres
EOF
cat > opt/metrics-agent/README <<'EOF'
metrics-agent 1.6.2
===================
Scrapes the local exporters and pushes the samples to the central push
gateway every 15 seconds. Config: /etc/metrics-agent/agent.yaml

Install: copy the binary to /opt/metrics-agent/bin, install the unit file,
then `systemctl enable --now metrics-agent`.
EOF
cat > opt/metrics-agent/bin/metrics-agent <<'EOF'
#!/bin/bash
# metrics-agent 1.6.2: pushes local exporter metrics to the gateway every 15s
echo "metrics-agent 1.6.2 starting, config /etc/metrics-agent/agent.yaml"
echo "push gateway http://10.0.5.9:9091, 2 targets, interval 15s"
while :; do
  sleep 15
  echo "pushed $((180 + RANDOM % 60)) series to 10.0.5.9:9091"
done
EOF
cat > opt/shop/bin/shop-api <<'EOF'
#!/bin/bash
echo "shop-api listening on :8080"
while :; do sleep 60; echo "healthz ok"; done
EOF
cat > opt/shop/bin/shop-cache <<'EOF'
#!/bin/bash
echo "shop-cache warm, 4096 MB arena"
while :; do sleep 90; echo "evicted $((RANDOM % 300)) keys"; done
EOF
chmod +x opt/metrics-agent/bin/metrics-agent opt/shop/bin/*

# Written last month by copying a unit from a workstation.
cat > etc/systemd/system/metrics-agent.service <<'EOF'
[Unit]
Description=Metrics push agent
Documentation=file:///opt/metrics-agent/README
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/opt/metrics-agent/bin/metrics-agent --config /etc/metrics-agent/agent.yaml
Restart=on-failure
RestartSec=10

[Install]
WantedBy=graphical.target
EOF
for s in shop-api shop-cache; do
  cat > "etc/systemd/system/$s.service" <<EOF
[Unit]
Description=Shop ${s#shop-} service
After=network-online.target

[Service]
ExecStart=/opt/shop/bin/$s
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
done

./bin/systemctl enable metrics-agent.service shop-api.service shop-cache.service >/dev/null 2>&1
# The reboot drill.
./bin/systemctl mock-boot >/dev/null 2>&1
exit 0
