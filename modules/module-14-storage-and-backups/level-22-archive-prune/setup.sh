#!/bin/bash
# The player writes prune.sh. Setup gives them a stub, a sample backups/ directory
# (relative to the fixed date 2026-11-10, so they can try things by hand) and the
# policy. The validator builds its own fixtures with several TODAY values.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state backups
TODAY=2026-11-10
for i in $(seq 0 420); do
  d=$(date -u -d "$TODAY - $i days" +%F)
  dow=$(date -u -d "$d" +%u); dom=${d:8:2}
  if [ "$i" -lt 12 ] || [ "$dow" = 7 ] || [ "$dom" = 01 ] || [ $((RANDOM % 6)) = 0 ]; then
    [ "$dow" = 7 ] && [ $((RANDOM % 5)) = 0 ] && [ "$i" -gt 11 ] && continue   # a Sunday that was never made
    head -c 64 /dev/urandom > "backups/db-$d.tar.zst"
  fi
done
touch "backups/db-2026-13-40.tar.zst" "backups/db-2026-11-3.tar.zst" "backups/db-final.tar.zst" "backups/db-2026-11-03.tar.zst.partial" backups/notes.txt
ln -s "db-$TODAY.tar.zst" backups/db-latest.tar.zst

cat > prune.sh <<'EOT'
#!/bin/bash
# TODO: retention for backups/db-YYYY-MM-DD.tar.zst, see POLICY.txt
echo "prune.sh is not written yet" >&2
exit 1
EOT
chmod +x prune.sh

cat > POLICY.txt <<'EOT'
Retention policy for the database dumps (backups/db-YYYY-MM-DD.tar.zst)

Take TODAY from the environment variable TODAY (YYYY-MM-DD), defaulting to the
real date, so the script can be tested for any day. Keep a backup if ANY of:

  daily    its date is within the last 7 days: TODAY-6 ... TODAY
  weekly   it is the newest backup of one of the last 4 weeks. A week runs
           Monday..Sunday and is identified by its Sunday; the 4 weeks are the
           ones ending on the last 4 Sundays on or before TODAY. (Normally
           that backup is the Sunday one; if the Sunday backup is missing, the
           newest earlier one of that week counts instead.)
  monthly  its date is the 1st of a month, from the month of TODAY back 12
           months in total (TODAY in November 2026: 2025-12-01 ... 2026-11-01)
  future   it is dated after TODAY (never delete those)

Everything else that is a backup is deleted. A file in backups/ whose name is
not exactly db-YYYY-MM-DD.tar.zst with a real calendar date (including the
db-latest.tar.zst symlink, partial uploads, notes...) is not a backup: skip it,
never delete it.

prune.sh behaviour
  ./prune.sh            dry run: delete nothing, print "would delete NAME" for
                        every file that would go (NAME = file name only)
  ./prune.sh --apply    delete them, printing "deleted NAME" for each
  anything else         print a usage line on stderr, exit 2, touch nothing
prune.sh works on the backups/ directory next to the script, wherever it is
started from. backups/ here is a sample for TODAY=2026-11-10.
EOT
