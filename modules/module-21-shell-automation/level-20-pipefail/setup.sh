#!/bin/bash
# 20-Byte Backups: backup_db.sh pipes pg_dump into gzip. A pipeline's status
# is gzip's, so a dump that dies halfway still "succeeds" and leaves a tiny
# .gz. Turning on pipefail fixes that but breaks the warning count: grep
# exits 1 when there are no warnings.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p bin backups

cat > bin/pg_dump <<'MOCK'
#!/bin/bash
# pg_dump - stand-in for PostgreSQL's pg_dump (prints a plain SQL dump).
#   PGDUMP_WARNINGS=N  print N warnings on stderr (default 2)
#   PGDUMP_FAIL=1      lose the connection halfway: error on stderr, exit 1
db="${1:-postgres}"
rows=400
w="${PGDUMP_WARNINGS:-2}"
i=0
while [ "$i" -lt "$w" ]; do
  echo "pg_dump: warning: there are circular foreign-key constraints on table \"orders_$i\"" >&2
  i=$((i + 1))
done
echo "-- PostgreSQL database dump of $db"
echo "SET client_encoding = 'UTF8';"
echo "CREATE TABLE public.orders (id integer PRIMARY KEY, customer text, total numeric(10,2));"
i=1
while [ "$i" -le "$rows" ]; do
  if [ "${PGDUMP_FAIL:-0}" = 1 ] && [ "$i" -gt $((rows / 2)) ]; then
    echo "pg_dump: error: Dumping the contents of table \"orders\" failed: PQgetResult() failed." >&2
    echo "pg_dump: error: connection to server was lost" >&2
    exit 1
  fi
  echo "INSERT INTO public.orders VALUES ($i, 'customer-$((i * 7 % 113))', $((i * 31 % 900)).$((i % 90 + 10)));"
  i=$((i + 1))
done
echo "-- PostgreSQL database dump complete"
MOCK
chmod +x bin/pg_dump

cat > backup_db.sh <<'SCRIPT'
#!/bin/bash
# backup_db.sh - nightly dump of the shop database to backups/db.sql.gz
# pg_dump's messages go to backups/dump.log.
set -e
mkdir -p backups
./bin/pg_dump shop 2> backups/dump.log | gzip > backups/db.sql.gz
warnings=$(grep 'warning' backups/dump.log | wc -l)
echo "backup ok: backups/db.sql.gz ($warnings warnings)"
SCRIPT
chmod +x backup_db.sh

cat > RESTORE_DRILL.txt <<'TXT'
Restore drill, Monday: the last 9 nightly backups are 20 bytes each.
  $ ls -l backups/            ->  db.sql.gz  20 bytes
  $ zcat backups/db.sql.gz    ->  (nothing)
Every night the job log said "backup ok". The database host had been
dropping connections since the network change.

Replay the bad night:       PGDUMP_FAIL=1 ./backup_db.sh; echo $?; ls -l backups
A night without warnings:   PGDUMP_WARNINGS=0 ./backup_db.sh; echo $?
TXT
