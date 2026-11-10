#!/bin/bash
last=$(grep -E ' DEPLOY [0-9.]+ ok$' deploy.log | awk '{print $3}' | while read -r v; do grep -q " ROLLBACK $v -> " deploy.log || echo "$v"; done | tail -n 1)
ln -sfn "releases/$last" current.new && mv -T current.new current
kill -HUP "$(cat run/app.pid)"
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) ROLLBACK 1.6.0 -> $last health 500 after deploy" >> deploy.log
sleep 0.5
curl -s "http://127.0.0.1:$(cat app.port)/health"
