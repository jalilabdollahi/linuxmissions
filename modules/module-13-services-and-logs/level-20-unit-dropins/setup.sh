#!/bin/bash
# Vendor unit: vendor-agent.service ships in usr/lib/systemd/system (package
# owned, overwritten on upgrade) and runs the agent with the vendor's flags
# (--interval 60, uploading to the vendor's cloud). TICKET.md wants other
# flags and an extra environment variable (random per setup). The player must
# use a drop-in (etc/systemd/system/vendor-agent.service.d/*.conf), reset
# ExecStart= first, daemon-reload and restart. The agent is running with the
# vendor flags when the level starts. Mock systemctl/journalctl in bin/.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
M="$(dirname "$0")/../../../mocks"
mkdir -p bin .lm .lm-state etc/systemd/system/multi-user.target.wants usr/lib/systemd/system opt/vendor-agent/bin var/log/journal
cp "$M/systemd/systemctl" "$M/systemd/journalctl" bin/
echo mon-01 > etc/hostname
echo "2026-11-10 10:15:00" > .lm/now

python3 - "$RANDOM$$" <<'PY'
import random, sys
R = random.Random(int(sys.argv[1]))
interval = R.choice([15, 20, 30, 45])
label = R.choice(["prod-eu", "prod-us", "staging", "edge-2"])
cluster = R.choice(["blue", "green", "amber", "teal"])
with open(".lm-state/want", "w") as f:
    f.write("INTERVAL=%d\nLABEL=%s\nCLUSTER=%s\n" % (interval, label, cluster))
PY
. .lm-state/want

cat > opt/vendor-agent/bin/agent <<'LMEND2'
#!/bin/bash
# vendor-agent (stand-in): collects host metrics. Flags: --interval S,
# --label NAME, --upload URL | --no-upload.
echo "vendor-agent 4.8.1 starting: args: $*"
echo "vendor-agent: AGENT_LOG=${AGENT_LOG:-unset} AGENT_CLUSTER=${AGENT_CLUSTER:-unset}"
while :; do
  sleep 20
  echo "vendor-agent: collected 212 metrics"
done
LMEND2
chmod +x opt/vendor-agent/bin/agent

cat > usr/lib/systemd/system/vendor-agent.service <<'LMEND2'
[Unit]
Description=Vendor monitoring agent
Documentation=https://docs.vendor.example/agent
After=network.target

[Service]
Type=simple
Environment=AGENT_LOG=info
ExecStart=/opt/vendor-agent/bin/agent --interval 60 --upload https://telemetry.vendor.example/ingest
Restart=on-failure

[Install]
WantedBy=multi-user.target
LMEND2
sha256sum usr/lib/systemd/system/vendor-agent.service > .lm-state/vendor.sha
bin/systemctl enable vendor-agent.service >/dev/null 2>&1
bin/systemctl start vendor-agent.service
bin/systemctl show -P MainPID vendor-agent.service > .lm-state/pid

cat > TICKET.md <<LMEND2
# CHG-2291: vendor-agent settings for mon-01

The monitoring vendor's agent runs with the vendor's defaults. Our policy:

- run it with exactly these flags:   --interval $INTERVAL --no-upload --label $LABEL
  (same binary as now: /opt/vendor-agent/bin/agent; the vendor's own
  --interval 60 and --upload ... flags must go)
- give it one more environment variable:   AGENT_CLUSTER=$CLUSTER
  (the vendor's Environment=AGENT_LOG=info stays)

The unit file belongs to the vendor package and is replaced on every upgrade:
do not edit it, and do not copy it. Restart the agent so it runs with the new
settings.
LMEND2
