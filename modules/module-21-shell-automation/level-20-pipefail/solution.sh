#!/bin/bash
# Reference solution: pipefail, the pipeline as an if condition so the script
# can read PIPESTATUS and clean up, and a warning count that tolerates zero.
cat > backup_db.sh <<'SCRIPT'
#!/bin/bash
# backup_db.sh - nightly dump of the shop database to backups/db.sql.gz
# pg_dump's messages go to backups/dump.log.
set -euo pipefail
mkdir -p backups
if ! ./bin/pg_dump shop 2> backups/dump.log | gzip > backups/db.sql.gz; then
  rc=("${PIPESTATUS[@]}")
  rm -f backups/db.sql.gz
  if [ "${rc[0]}" -ne 0 ]; then
    echo "backup FAILED: pg_dump exited ${rc[0]} (see backups/dump.log)" >&2
  else
    echo "backup FAILED: gzip exited ${rc[1]}" >&2
  fi
  exit 1
fi
warnings=$(grep -c 'warning' backups/dump.log || true)
echo "backup ok: backups/db.sql.gz ($warnings warnings)"
SCRIPT
./backup_db.sh
PGDUMP_FAIL=1 ./backup_db.sh
echo "exit $?"
PGDUMP_WARNINGS=0 ./backup_db.sh
