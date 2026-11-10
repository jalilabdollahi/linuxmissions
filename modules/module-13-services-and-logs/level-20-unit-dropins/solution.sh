#!/bin/bash
. .lm-state/want
mkdir -p etc/systemd/system/vendor-agent.service.d
cat > etc/systemd/system/vendor-agent.service.d/override.conf <<EOF
[Service]
Environment=AGENT_CLUSTER=$CLUSTER
ExecStart=
ExecStart=/opt/vendor-agent/bin/agent --interval $INTERVAL --no-upload --label $LABEL
EOF
bin/systemctl daemon-reload
bin/systemctl restart vendor-agent.service
