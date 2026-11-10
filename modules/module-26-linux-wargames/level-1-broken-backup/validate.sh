#!/bin/bash
# Final state: backup.sh archives the whole share when run the way cron runs
# it (env -i), a new archive made after the incident restores it exactly, and
# a failing tar makes the script exit non-zero.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
SRC="office share/data"
if [ ! -x backup.sh ] || [ ! -d "$SRC" ] || [ ! -f .lm-state/stamp ]; then
  echo "❌ backup.sh or the data tree is missing; type 'reset'"; exit 1
fi
TMP=$(mktemp -d); trap 'chmod -R u+rwx "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT

compare() {   # archive label
  local x="$TMP/x"; rm -rf "$x"; mkdir -p "$x"
  if ! tar -xzf "$1" -C "$x" 2>/dev/null; then echo "❌ $2 is not a readable archive"; return 1; fi
  if ! d=$(diff -r "$x" "$SRC" 2>&1); then
    echo "❌ $2 does not restore the whole data tree: $(echo "$d" | head -1 | cut -c1-110)"; return 1
  fi
  return 0
}

newest=$(find backups -name '*.tar.gz' -newer .lm-state/stamp -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)
if [ -z "$newest" ]; then
  echo "❌ no new archive in backups/ since the restore test; run a fresh backup once it is fixed"; exit 1
fi
compare "$newest" "the newest archive ($(basename "$newest"))" || exit 1

# the script itself, in cron's environment
mkdir -p "$TMP/home" "$TMP/cwd"
before=$(ls backups | wc -l)
sleep 1   # archive names carry seconds
(cd "$TMP/cwd" && env -i PATH=/usr/bin:/bin HOME="$TMP/home" SHELL=/bin/sh "$SANDBOX/backup.sh" >/dev/null 2>&1)
rc=$?
if [ "$rc" -ne 0 ]; then echo "❌ backup.sh exits $rc when run from cron's environment"; exit 1; fi
if [ "$(ls backups | wc -l)" -le "$before" ]; then echo "❌ backup.sh ran but wrote no new archive when started from another directory"; exit 1; fi
mine=$(ls -t backups/*.tar.gz | head -1)
compare "$mine" "the archive backup.sh makes under cron" || exit 1

# an unreadable file must make the script fail, not "succeed"
cp -a "$SANDBOX" "$TMP/copy"
chmod 000 "$TMP/copy/$SRC/db/dump.sql"
(cd "$TMP/cwd" && env -i PATH=/usr/bin:/bin HOME="$TMP/home" "$TMP/copy/backup.sh" >/dev/null 2>&1)
if [ $? -eq 0 ]; then
  echo "❌ backup.sh still reports success when tar cannot read a file"; exit 1
fi
echo "✅ the backup restores the whole share, runs under cron's environment and fails loudly when tar fails"
