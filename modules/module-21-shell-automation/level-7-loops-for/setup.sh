#!/bin/bash
# A backup directory with gaps, zero-byte dumps and decoys (.part, .sql),
# plus a stub missing_backups.sh. The month boundary sits in the middle.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p backups

for d in 2026-10-25 2026-10-26 2026-10-27 2026-10-28 2026-10-30 2026-11-04 \
         2026-11-06 2026-11-07 2026-11-08 2026-11-09; do
  printf 'pg_dump of %s\n' "$d" | gzip -c > "backups/db-$d.sql.gz"
done
: > backups/db-2026-11-03.sql.gz                           # dump crashed: 0 bytes
printf 'partial' > backups/db-2026-11-02.sql.gz.part        # never finished
printf 'plain dump\n' > backups/db-2026-11-05.sql           # forgot to compress
printf 'see wiki: restore procedure\n' > backups/README

cat > missing_backups.sh <<'EOF'
#!/bin/bash
# missing_backups.sh START END
#   START and END are dates (YYYY-MM-DD), both included.
#   For every day from START to END, in order, print the day (YYYY-MM-DD) if
#   backups/db-<day>.sql.gz is missing or empty (0 bytes).
#   Exit 0 if nothing is missing, 1 if at least one day was printed.
#   Wrong usage (not exactly 2 arguments, a date that does not exist, END
#   before START): a message on stderr, nothing on stdout, exit 2.

# TODO
EOF
chmod +x missing_backups.sh

cat > REQUEST.txt <<'EOF'
From: dba@example.internal
Can you tell me which nightly dumps we are missing between 2026-10-28 and
2026-11-03? Some nights the job "succeeds" with an empty file. I will need
the same check for other ranges (the end of the year, too), so a script
would be great: ./missing_backups.sh 2026-10-28 2026-11-03
EOF
