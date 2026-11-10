#!/bin/bash
# app: requires db-proxy and starts after it; db-proxy: drop the stray After=app.service.
sed -i 's/^Wants=db-proxy.service/Requires=db-proxy.service\nAfter=db-proxy.service/' etc/systemd/system/app.service
sed -i 's/^After=network.target app.service/After=network.target/' etc/systemd/system/db-proxy.service
bin/systemctl daemon-reload
bin/systemctl mock-boot
