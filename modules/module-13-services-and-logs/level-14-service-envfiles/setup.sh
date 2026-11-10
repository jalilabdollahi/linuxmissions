#!/bin/bash
# Wrong database: billing.service should connect to the new primary that
# config management wrote into /etc/billing/env, but it still uses the
# legacy one. Why:
#   - the unit loads EnvironmentFile=-/etc/biling/env (typo); the "-" makes
#     a missing file silently fine, so systemd never complains;
#   - the vendor defaults in /etc/default/billing still say legacy, and an
#     EnvironmentFile= overrides Environment= (editing Environment= in the
#     unit changes nothing);
#   - once the typo is fixed, the env file's "DB_PORT=6432   # via pgbouncer"
#     breaks: systemd has no inline comments, the value includes "# via ...".
# New host and port are random per setup. Mock systemctl/journalctl in bin/.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
M="$(dirname "$0")/../../../mocks"
mkdir -p bin .lm .lm-state etc/default etc/billing etc/systemd/system/multi-user.target.wants opt/billing/bin
cp "$M/systemd/systemctl" "$M/systemd/journalctl" bin/
echo billing-01 > etc/hostname
echo "2026-11-10 10:05:00" > .lm/now

NEW_HOST="pg-billing-$(printf '%04x' $RANDOM).prod.internal"
PORTS=(6432 6433 5433 6543)
NEW_PORT=${PORTS[RANDOM % 4]}

cat > opt/billing/bin/billing-server <<'EOF'
#!/bin/bash
# billing-server 7.4.1 (vendor build). Configuration comes from the
# environment only: DB_HOST, DB_PORT, DB_NAME, LOG_FORMAT.
echo "billing-server 7.4.1 starting (pid $$)"
case "$DB_PORT" in
  ''|*[!0-9]*)
    echo "FATAL: invalid DB_PORT '$DB_PORT': expected a port number" >&2
    exit 78 ;;
esac
echo "connecting to postgres://billing@$DB_HOST:$DB_PORT/${DB_NAME:-billing}"
case "$DB_HOST" in
  pg-legacy-*)
    echo "WARNING: $DB_HOST is the decommissioned primary (read-only since 2026-11-03); invoices will not be saved" >&2 ;;
  *)
    echo "connected to $DB_HOST:$DB_PORT, schema version 212, ready" ;;
esac
while :; do
  sleep 20
  echo "invoice batch: $((RANDOM % 30)) invoices processed"
done
EOF
chmod 755 opt/billing/bin/billing-server
cksum < opt/billing/bin/billing-server > .lm-state/binary.sum

cat > etc/default/billing <<'EOF'
# Defaults shipped with the billing-server package.
# Do not edit: this file is replaced on upgrade. Site settings go to
# /etc/billing/env, which is read after this file.
DB_HOST=pg-legacy-01.internal
DB_PORT=5432
DB_NAME=billing
LOG_FORMAT=json
EOF

cat > etc/billing/env <<EOF
# Managed by config management (CHG-4410): billing moves to the new primary.
DB_HOST=$NEW_HOST
DB_PORT=$NEW_PORT      # via pgbouncer
DB_NAME=billing
EOF

cat > etc/systemd/system/billing.service <<'EOF'
[Unit]
Description=Billing service (invoices and payments)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=billing
Environment=DB_HOST=pg-legacy-01.internal DB_PORT=5432 LOG_FORMAT=text
EnvironmentFile=/etc/default/billing
EnvironmentFile=-/etc/biling/env
ExecStart=/opt/billing/bin/billing-server
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
ln -s /etc/systemd/system/billing.service etc/systemd/system/multi-user.target.wants/billing.service

cat > TICKET.txt <<EOF
CHG-4410  billing: move to the new database primary
---------------------------------------------------
The legacy primary pg-legacy-01 is read-only since Nov 3. billing must use

    DB_HOST=$NEW_HOST
    DB_PORT=$NEW_PORT   (pgbouncer)

Config management already wrote these into /etc/billing/env, but billing still
talks to pg-legacy-01. Keep the values in /etc/billing/env (that's the file
config management owns), don't touch the vendor binary, and get billing
running on the new primary.
EOF
echo "$NEW_HOST $NEW_PORT" > .lm-state/want

bin/systemctl daemon-reload
bin/systemctl start billing.service >/dev/null 2>&1
