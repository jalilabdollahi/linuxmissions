#!/bin/bash
# The Backup That Never Ran: etc/cron.daily/db-backup.sh is skipped by
# run-parts for two reasons: its name contains a dot and it is not executable.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
# run-parts is real on Ubuntu; the mock (same debianutils rules) makes it work
# on macOS too. cron-run lets the player run the daily job on a simulated clock.
bash "$MOCKS/cron/install.sh" "$SANDBOX" --now "2025-05-14 06:00" run-parts cron-run >/dev/null

mkdir -p etc/cron.daily var/backups var/log data

cat > data/shop.sql <<'SQL'
-- shop database, dumped by pg_dump (fixture)
CREATE TABLE orders (id integer PRIMARY KEY, customer text, total numeric);
INSERT INTO orders VALUES (1, 'Lena Fischer', 41.90);
INSERT INTO orders VALUES (2, 'Kofi Mensah', 128.00);
INSERT INTO orders VALUES (3, 'Aiko Tanaka', 15.25);
SQL

cat > etc/cron.daily/db-backup.sh <<'SH'
#!/bin/sh
# db-backup: dump the shop database once a day, keep 30 days.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/var/backups/db-$(date +%F).sql.gz"
gzip -c "$ROOT/data/shop.sql" > "$OUT.tmp"
mv "$OUT.tmp" "$OUT"
find "$ROOT/var/backups" -name 'db-*.sql.gz' -mtime +30 -delete
echo "db-backup: wrote $(basename "$OUT")"
SH
chmod 644 etc/cron.daily/db-backup.sh

cat > etc/cron.daily/logrotate <<'SH'
#!/bin/sh
# rotate the app logs (stand-in for the real logrotate job)
echo "logrotate: nothing to rotate"
SH
cat > etc/cron.daily/man-db <<'SH'
#!/bin/sh
# keep the man page index fresh (stand-in)
exit 0
SH
cat > etc/cron.daily/apt-compat <<'SH'
#!/bin/sh
# apt's daily housekeeping (stand-in)
exit 0
SH
chmod 755 etc/cron.daily/logrotate etc/cron.daily/man-db etc/cron.daily/apt-compat
: > etc/cron.daily/.placeholder

for d in 10 11 12 13; do
  printf 'May %s 06:25:01 db1 CRON[%s]: (root) CMD (cd / && run-parts --report /etc/cron.daily)\n' "$d" "$((4100 + d * 37))"
  printf 'May %s 06:25:01 db1 CRON[%s]: (CRON) info (No MTA installed, discarding output)\n' "$d" "$((4100 + d * 37))"
done > var/log/cron.log
