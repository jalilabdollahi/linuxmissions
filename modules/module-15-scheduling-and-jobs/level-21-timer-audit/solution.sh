#!/bin/bash
cd etc/systemd/system || exit 1
sed -i.bak 's/^\[Timers\]/[Timer]/' report-weekly.timer
sed -i.bak 's/25:00:00/02:00:00/' db-vacuum.timer
mv certbot-renew.service cert-renew.service
printf '\n[Install]\nWantedBy=timers.target\n' >> sessions-purge.timer
cd ../../..
printf '%s\n' cert-renew.timer db-vacuum.timer report-weekly.timer sessions-purge.timer > broken.txt
