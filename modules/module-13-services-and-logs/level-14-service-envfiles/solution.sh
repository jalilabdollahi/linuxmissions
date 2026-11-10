#!/bin/bash
# Which env files does systemd load, and in which order? The site file has a
# typo (and "-" hides it), and its DB_PORT line carries an inline comment.
bin/systemctl show -p Environment -p EnvironmentFiles billing.service
sed -i 's|^EnvironmentFile=-/etc/biling/env$|EnvironmentFile=-/etc/billing/env|' etc/systemd/system/billing.service
sed -i 's|^\(DB_PORT=[0-9]*\)[[:space:]]*#.*$|\1|' etc/billing/env
cat etc/billing/env
bin/systemctl daemon-reload
bin/systemctl restart billing.service
bin/systemctl status billing.service
