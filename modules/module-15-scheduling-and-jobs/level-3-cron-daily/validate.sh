#!/bin/bash
# run-parts --test must list the backup script, and a simulated 06:25 cron
# run of etc/cron.daily must really execute it and produce the dump.
SANDBOX="$1"
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
DAILY="$SANDBOX/etc/cron.daily"
cd "$SANDBOX" || exit 1

if [ ! -d "$DAILY" ]; then
  echo "❌ etc/cron.daily is missing; type reset to start over"
  exit 1
fi

# The backup script, whatever it is called now.
copies=()
while IFS= read -r f; do copies+=("$f"); done < <(grep -l '^# db-backup: dump the shop database' "$DAILY"/* "$DAILY"/.[!.]* 2>/dev/null)
if [ ${#copies[@]} -eq 0 ]; then
  echo "❌ the backup script is no longer in etc/cron.daily; type reset to get it back"
  exit 1
fi

listed="$(python3 "$MOCKS/cron/run-parts" --test "$DAILY" 2>/dev/null)"
active=()
for f in "${copies[@]}"; do
  if printf '%s\n' "$listed" | grep -Fxq "$f"; then active+=("$f"); fi
done
if [ ${#active[@]} -eq 0 ]; then
  f="${copies[0]}"; name="${f##*/}"
  if [ -x "$f" ]; then
    echo "❌ $name is executable now, but run-parts --test etc/cron.daily still does not list it"
  elif printf '%s' "$name" | grep -Eq '^[A-Za-z0-9_-]+$'; then
    echo "❌ run-parts --test etc/cron.daily still skips $name: run-parts only runs files it may execute"
  else
    echo "❌ run-parts --test etc/cron.daily does not list $name"
  fi
  exit 1
fi
if [ ${#active[@]} -gt 1 ]; then
  echo "❌ run-parts would run the backup ${#active[@]} times (${active[*]##*/}); keep one copy"
  exit 1
fi
for other in logrotate man-db apt-compat; do
  if ! printf '%s\n' "$listed" | grep -Fxq "$DAILY/$other"; then
    echo "❌ etc/cron.daily/$other no longer runs; leave the other scripts alone"
    exit 1
  fi
done

head1="$(head -n 1 "${active[0]}")"
if [ "$head1" != '#!/bin/sh' ]; then
  echo "❌ the first line of ${active[0]##*/} is no longer #!/bin/sh"
  exit 1
fi

# Run cron's 06:25 cron.daily job on a simulated day and look for the dump.
DAY=2025-05-14
OUT="$SANDBOX/var/backups/db-$DAY.sql.gz"
rm -f "$OUT"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"; rm -f "$OUT" "$OUT.tmp"' EXIT
python3 "$MOCKS/cron/cron-run" --root "$SANDBOX" --spool "$TMP/spool" --from "$DAY 06:00" --to "$DAY 07:00" \
  -q --jsonl "$TMP/runs.jsonl" >/dev/null 2>&1
output="$(python3 -c 'import json,sys
for l in open(sys.argv[1]):
    r = json.loads(l)
    if r["source"].endswith("cron.daily"): print(r["output"])' "$TMP/runs.jsonl" 2>/dev/null)"
if ! printf '%s\n' "$output" | grep -q "db-backup: wrote db-$DAY.sql.gz"; then
  err="$(printf '%s\n' "$output" | grep -m1 -iE 'error|denied|not found|exited')"
  echo "❌ in a simulated 06:25 cron.daily run the backup did not complete${err:+: $err}"
  exit 1
fi
if [ ! -f "$OUT" ] || ! gzip -dc "$OUT" 2>/dev/null | cmp -s - "$SANDBOX/data/shop.sql"; then
  echo "❌ the backup ran but var/backups/db-$DAY.sql.gz is not a gzip copy of data/shop.sql; keep the script's code as it was"
  exit 1
fi
echo "✅ run-parts now runs the backup every morning and it writes var/backups/db-<date>.sql.gz"
exit 0
