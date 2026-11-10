#!/bin/bash
# Restart only after failures, wait between attempts, and raise the start limit.
cat > etc/systemd/system/queue-consumer.service <<EOF
[Unit]
Description=Queue consumer (jobs from the broker)
After=network.target
StartLimitIntervalSec=$(grep ^INTERVALSEC .lm-state/want | cut -d= -f2)
StartLimitBurst=$(grep ^BURST .lm-state/want | cut -d= -f2)

[Service]
Type=simple
ExecStart=/opt/queue/bin/queue-consumer
Restart=on-failure
RestartSec=$(grep ^RESTARTSEC .lm-state/want | cut -d= -f2)

[Install]
WantedBy=multi-user.target
EOF
bin/systemctl daemon-reload
bin/systemctl reset-failed queue-consumer.service
bin/systemctl start queue-consumer.service
