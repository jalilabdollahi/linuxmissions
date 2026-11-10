#!/bin/bash
cat > etc/systemd/system/report-api.service <<EOF
[Unit]
Description=Report API
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/report-api
ExecStart=/opt/report-api/bin/report-api --port $(cat .lm-state/port) --foreground
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
bin/systemd-analyze verify etc/systemd/system/report-api.service
bin/systemctl daemon-reload
bin/systemctl enable --now report-api.service
