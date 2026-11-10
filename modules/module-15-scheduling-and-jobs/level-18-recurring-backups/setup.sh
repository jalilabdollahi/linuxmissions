#!/bin/bash
# The backup calendar: write backup.cron so a simulated 64-day cron run
# produces exactly the right (time, mode) pairs in backup-runs.log.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
bash "$MOCKS/cron/install.sh" "$SANDBOX" cron-run cron-expand >/dev/null

cat > backup.sh <<'EOF'
#!/bin/bash
# backup.sh MODE   -- the backup tool of the file server (stub for the exercise)
#   incremental  files changed since yesterday
#   full         everything, weekly baseline
#   archive      month-end style snapshot for the compliance vault
mode="$1"
case "$mode" in
  incremental|full|archive) ;;
  *) echo "usage: backup.sh incremental|full|archive" >&2; exit 2 ;;
esac
here="$(cd "$(dirname "$0")" && pwd)"
echo "$(date '+%F %H:%M') $mode" >> "$here/backup-runs.log"
echo "backup.sh: $mode backup done"
EOF
chmod +x backup.sh

cat > backup.cron <<'EOF'
# backup.cron -- file server fs01 (not installed yet)
# The old setup was one line, and it ran incrementals on Sundays and on the
# 1st too, on top of the other backups:
#   30 1 * * *  /srv/backup/backup.sh incremental
EOF

cat > BACKUP-PLAN.txt <<'EOF'
Backup calendar for fs01 (ticket INFRA-812)

  incremental   01:30, Monday to Saturday
  full          01:30, Sunday
  archive       03:00, on the 1st of every month

On the 1st only the archive runs at 03:00 as the monthly backup: there must be
no incremental that morning (the archive already contains everything). A full
backup on a Sunday that is also the 1st still happens, as every Sunday.

Write the jobs into backup.cron, calling this directory's backup.sh with the
mode as its argument (use its full path: cron does not start in this
directory). Do not install it yet: the infra team will review the file.
You can dry-run it with the cron-run tool in bin/ (see its --help).
EOF
