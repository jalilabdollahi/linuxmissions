#!/bin/bash
cat > backup.sh <<'SH'
#!/bin/bash
# Nightly backup of the office share. Run by cron at 02:00.
set -o pipefail
BASE=$(cd "$(dirname "$0")" && pwd)
SRC="$BASE/office share/data"
DEST=$BASE/backups
LOG=$BASE/logs/backup.log
OUT=$DEST/data-$(date +%F-%H%M%S).tar.gz

if ! tar -cf - -C "$SRC" . | gzip > "$OUT"; then
  echo "$(date '+%F %T') backup FAILED" >> "$LOG"
  rm -f "$OUT"
  exit 1
fi
echo "$(date '+%F %T') backup ok: $(basename "$OUT")" >> "$LOG"
SH
sleep 1
./backup.sh
