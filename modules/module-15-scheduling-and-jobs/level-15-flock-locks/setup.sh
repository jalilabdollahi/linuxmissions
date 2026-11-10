#!/bin/bash
# One At A Time: cron starts sync.sh every minute but a sync takes ~90 s, so
# runs overlap and interleave their writes into catalog.db.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm

cat > sync.sh <<'EOF'
#!/bin/bash
# sync.sh - pull the supplier catalog into catalog.db.
# Started by cron every minute (see crontab.txt). A full sync takes about
# 90 seconds; SYNC_SECONDS changes that for tests (keep this variable).
cd "$(dirname "$0")" || exit 1

echo "BEGIN $$ $(date '+%F %T')" >> catalog.db
sleep "${SYNC_SECONDS:-90}"            # download + import
echo "rows $((RANDOM % 400 + 12000)) $$" >> catalog.db
echo "END $$ $(date '+%F %T')" >> catalog.db
echo "sync finished"
EOF
chmod +x sync.sh
sha256sum sync.sh 2>/dev/null | cut -d' ' -f1 > .lm/orig.sha || shasum -a 256 sync.sh | cut -d' ' -f1 > .lm/orig.sha

cat > crontab.txt <<EOF
# crontab for catalog
MAILTO=ops@example.com
* * * * * $SANDBOX/sync.sh >> $SANDBOX/sync.log 2>&1
EOF

cat > catalog.db <<'EOF'
BEGIN 21877 2026-11-10 01:14:00
rows 12211 21877
END 21877 2026-11-10 01:15:31
BEGIN 21950 2026-11-10 01:16:00
BEGIN 22013 2026-11-10 01:17:00
rows 12374 21950
END 21950 2026-11-10 01:17:29
rows 12119 22013
BEGIN 22101 2026-11-10 01:18:00
END 22013 2026-11-10 01:18:33
EOF

cat > INCIDENT.txt <<'EOF'
INC-4471  catalog.db corrupted again
Since the supplier feed got bigger, a sync takes ~90 s, but cron starts a
new one every minute. Two imports writing at the same time leave a broken
catalog (see the interleaved BEGIN/END records in catalog.db).

Wanted: sync.sh itself refuses to start while another copy is running:
exit non-zero at once, with a message, without touching catalog.db.
Last year's attempt with a pidfile blocked all syncs for two days after the
OOM killer took out one run (kill -9: no cleanup ran), so think about that
case too. Keep the lock file in this directory.
EOF
