#!/bin/bash
# Every file of the expected final state exists with the exact content, mode and mtime;
# no other regular files; the set of directories is the backup's.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -d projects ] || { echo "❌ projects/ is gone"; exit 1; }
[ -f backups/projects-mon.tar.gz ] || { echo "❌ Monday's backup is gone"; exit 1; }

got_files=$(find projects -type f | LC_ALL=C sort)
want_files=$(cut -f1 .lm-state/expect.tsv)
if [ "$got_files" != "$want_files" ]; then
  missing=$(comm -13 <(printf '%s\n' "$got_files") <(printf '%s\n' "$want_files") | head -1)
  extra=$(comm -23 <(printf '%s\n' "$got_files") <(printf '%s\n' "$want_files") | head -1)
  if [ -n "$missing" ]; then
    echo "❌ still missing from projects/: $missing"
  else
    echo "❌ projects/ contains a file that should not be there: $extra (restore only what Monday's backup had)"
  fi
  exit 1
fi
while IFS=$'\t' read -r p mode mt h; do
  if [ "$(sha256sum < "$p" | cut -d' ' -f1)" != "$h" ]; then
    if grep -qxF "$p" .lm-state/restored; then echo "❌ $p was restored but its content is not Monday's version (wrong backup?)"
    else echo "❌ $p was edited since Monday and now has different content: restoring must not overwrite files that still exist"; fi
    exit 1
  fi
  if [ "$(stat -c %a "$p")" != "$mode" ]; then echo "❌ $p has mode $(stat -c %a "$p"), expected $mode (extract with the permissions stored in the archive)"; exit 1; fi
  if [ "$(stat -c %Y "$p")" != "$mt" ]; then echo "❌ the modification time of $p is not what it was in the backup/before (it must be preserved)"; exit 1; fi
done < .lm-state/expect.tsv
dirs=$(find projects -type d | LC_ALL=C sort)
if [ "$dirs" != "$(cat .lm-state/dirs)" ]; then echo "❌ the set of directories under projects/ is not the backup's (a deleted directory is not back, or a stray one was created)"; exit 1; fi
if [ "$(ls -A | LC_ALL=C sort | tr '\n' ' ')" != ".lm-state TICKET.txt backups projects " ]; then
  echo "❌ something was created in the level folder outside projects/ (a temporary extraction left behind?)"; exit 1
fi
echo "✅ the deleted files are back exactly as in Monday's backup, and today's work is untouched"
