#!/bin/bash
# Three cron helpers that work with `bash bin/x` or `python3 bin/x` but fail
# when cron runs them as ./bin/x, each for a different shebang reason:
#   disk_report  bash syntax ([[ ]]) under #!/bin/sh, which is dash on Ubuntu
#   queue_stats  a blank line above the shebang, so the kernel sees no #!
#   backup_age   an interpreter path that only existed on the old build box
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p bin data

cat > bin/disk_report <<'EOF'
#!/bin/sh
# disk_report DF_FILE - list filesystems at 80% or more from a `df -P` capture
limit=80
while read -r fs blocks used avail cap mount; do
  [[ $fs == Filesystem ]] && continue
  pct=${cap%\%}
  if [[ $pct -ge $limit ]]; then
    echo "FULL $mount $pct%"
  fi
done < "$1"
EOF

{
  echo
  cat <<'EOF'
#!/usr/bin/env python3
"""queue_stats QUEUE_FILE - count the jobs in each state (one 'ID STATE' per line)."""
import sys
from collections import Counter

counts = Counter()
with open(sys.argv[1]) as fh:
    for line in fh:
        parts = line.split()
        if len(parts) == 2:
            counts[parts[1]] += 1
print(" ".join(f"{state}={counts[state]}" for state in sorted(counts)))
EOF
} > bin/queue_stats

cat > bin/backup_age <<'EOF'
#!/opt/python3.11/bin/python3
"""backup_age LISTING - newest backup, how many there are and their total size.

LISTING has one "YYYY-MM-DD SIZE_IN_MB FILENAME" line per backup.
"""
import sys

rows = []
with open(sys.argv[1]) as fh:
    for line in fh:
        parts = line.split(None, 2)
        if len(parts) == 3:
            rows.append((parts[0], int(parts[1]), parts[2].strip()))
newest = max(rows)
print(f"newest={newest[0]} file={newest[2]} count={len(rows)} total_mb={sum(r[1] for r in rows)}")
EOF

chmod 755 bin/disk_report bin/queue_stats bin/backup_age

cat > data/df.txt <<'EOF'
Filesystem     1024-blocks      Used Available Capacity Mounted on
/dev/sda2         41152736  37450012   1589056      96% /
/dev/sda1           999320    205764    724744      23% /boot
/dev/sdb1        103081248  84529524  13286476      87% /var
/dev/sdc1        515928320 211530611 278167309      44% /srv
EOF

cat > data/queue.txt <<'EOF'
9101 done
9102 done
9103 failed
9104 pending
9105 done
9106 pending
EOF

cat > data/backups.txt <<'EOF'
2026-11-07 812 db-2026-11-07.sql.gz
2026-11-08 815 db-2026-11-08.sql.gz
2026-11-09 820 db-2026-11-09.sql.gz
EOF

cat > crontab.txt <<'EOF'
# ops crontab (cron runs every line with /bin/sh -c, in /srv/ops)
*/15 * * * *  ./bin/disk_report data/df.txt
*/5  * * * *  ./bin/queue_stats data/queue.txt
30   6 * * *  ./bin/backup_age data/backups.txt
EOF

cat > cron-mail.txt <<'EOF'
From: Cron Daemon <root@ops-01>
Subject: Cron <ops@ops-01> ./bin/disk_report data/df.txt

./bin/disk_report: 5: [[: not found
./bin/disk_report: 7: [[: not found
./bin/disk_report: 5: [[: not found
./bin/disk_report: 7: [[: not found
./bin/disk_report: 5: [[: not found
./bin/disk_report: 7: [[: not found
./bin/disk_report: 5: [[: not found
./bin/disk_report: 7: [[: not found
./bin/disk_report: 5: [[: not found
./bin/disk_report: 7: [[: not found

From: Cron Daemon <root@ops-01>
Subject: Cron <ops@ops-01> ./bin/queue_stats data/queue.txt

./bin/queue_stats: 3: queue_stats QUEUE_FILE - count the jobs in each state ("<id> <state>" lines).: not found
./bin/queue_stats: 4: import: not found
./bin/queue_stats: 5: from: not found
./bin/queue_stats: 7: Syntax error: "(" unexpected

From: Cron Daemon <root@ops-01>
Subject: Cron <ops@ops-01> ./bin/backup_age data/backups.txt

/bin/sh: 1: ./bin/backup_age: not found
EOF
