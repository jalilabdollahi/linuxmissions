#!/bin/bash
# Pager alert on app-02: one of four long-running services is in a crash loop
# (Restart=on-failure, it never gives up), so it shows "activating
# (auto-restart)" and never "failed": `systemctl --failed` lists nothing.
# A fifth unit is a oneshot export that finished with status 0 an hour ago:
# "inactive (dead)" is its healthy state. Which unit crashes and with which
# exit code is random per setup. The mock systemctl/journalctl live in bin/
# and treat the sandbox as "/".
SANDBOX="$1"
cd "$SANDBOX" || exit 1
M="$(dirname "$0")/../../../mocks"

mkdir -p bin etc/systemd/system/multi-user.target.wants opt .lm-state \
         etc/billing etc/order-worker etc/search-indexer etc/notify-gateway var/lib/export
cp "$M/systemd/systemctl" "$M/systemd/journalctl" bin/
echo app-02 > etc/hostname
ln -s /usr/lib/systemd/system/multi-user.target etc/systemd/system/default.target

SERVICES=(billing-api order-worker search-indexer notify-gateway)
BROKEN=${SERVICES[RANDOM % 4]}
CODES=(1 2 64 69 70 75 76 78)
CODE=${CODES[RANDOM % ${#CODES[@]}]}

# What the crashing binary says before it exits, by exit code.
case $CODE in
  1)  WHY="Error: connect ECONNREFUSED 10.0.3.15:5432 (database primary)" ;;
  2)  WHY="flag provided but not defined: -queue-v2" ;;
  64) WHY="usage: unknown option --threads=auto" ;;
  69) WHY="upstream 10.0.3.40:6379 unavailable, refusing to start" ;;
  70) WHY="internal error: schema checksum mismatch (expected 9c1f, got 77ab)" ;;
  75) WHY="lock /run/lock/worker.lock held by another instance, try again later" ;;
  76) WHY="protocol error: broker speaks AMQP 0-9-1, client requires 1.0" ;;
  78) WHY="config error: required key 'tls.cert' missing" ;;
esac

# One long-running script per service, each with its own startup chatter.
healthy() {   # name  first-line  periodic-line  interval
  cat > "opt/$1/bin/$1" <<EOF
#!/bin/bash
echo "$2"
n=0
while :; do
  sleep $4
  n=\$((n + 1))
  echo "$3 (\$n)"
done
EOF
}
for s in "${SERVICES[@]}"; do
  mkdir -p "opt/$s/bin"
  case $s in
    billing-api)     healthy $s "billing-api 4.12.0 listening on 127.0.0.1:8081" "served requests, p99 41ms" 53 ;;
    order-worker)    healthy $s "order-worker 3.2.1 consuming queue 'orders' (prefetch 20)" "acked batch of 20 orders" 37 ;;
    search-indexer)  healthy $s "search-indexer 1.9.4: index 'products' opened, 182311 docs" "indexed delta, 0 errors" 61 ;;
    notify-gateway)  healthy $s "notify-gateway 2.0.7 connected to smtp relay 10.0.3.25:587" "flushed outbound mail queue" 44 ;;
  esac
done
cat > "opt/$BROKEN/bin/$BROKEN" <<EOF
#!/bin/bash
echo "$BROKEN starting (pid \$\$)"
echo "$WHY" >&2
exit $CODE
EOF
chmod +x opt/*/bin/*

unit() {   # name  description  extra-[Unit]-lines  extra-[Service]-lines
  cat > "etc/systemd/system/$1.service" <<EOF
[Unit]
Description=$2
After=network-online.target
Wants=network-online.target
$3
[Service]
Type=simple
User=app
ExecStart=/opt/$1/bin/$1
Restart=on-failure
RestartSec=5
$4
[Install]
WantedBy=multi-user.target
EOF
  ln -s "/etc/systemd/system/$1.service" "etc/systemd/system/multi-user.target.wants/$1.service"
}
unit billing-api    "Billing API"                 "" "Environment=BILLING_ENV=production"
unit order-worker   "Order queue worker"          "StartLimitIntervalSec=0" ""
unit search-indexer "Product search indexer"      "StartLimitIntervalSec=0" "Nice=5"
unit notify-gateway "Outbound notification relay" "" "EnvironmentFile=-/etc/notify-gateway/env"
# Without a start limit the crashing unit keeps cycling forever, as the
# vendor configured it ("never give up").
grep -q StartLimitIntervalSec "etc/systemd/system/$BROKEN.service" ||
  sed -i "s/^Wants=network-online.target$/&\nStartLimitIntervalSec=0/" "etc/systemd/system/$BROKEN.service"

cat > opt/nightly-export.sh <<'EOF'
#!/bin/bash
echo "export: dumping invoices for $(date -d yesterday +%F)"
echo "export: wrote 4127 rows to /var/lib/export/invoices.csv"
EOF
chmod +x opt/nightly-export.sh
cat > etc/systemd/system/nightly-export.service <<'EOF'
[Unit]
Description=Nightly invoice export
After=billing-api.service

[Service]
Type=oneshot
User=app
ExecStart=/opt/nightly-export.sh
EOF

./bin/systemctl daemon-reload
./bin/systemctl start nightly-export.service
./bin/systemctl start billing-api order-worker search-indexer notify-gateway
sleep 0.3

printf '%s' "$BROKEN.service" | sha256sum | cut -d' ' -f1 > .lm-state/unit.sha
printf '%s' "$CODE" | sha256sum | cut -d' ' -f1 > .lm-state/code.sha
