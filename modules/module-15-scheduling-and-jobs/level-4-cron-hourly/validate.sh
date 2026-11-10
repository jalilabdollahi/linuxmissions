#!/bin/bash
# Run crontab.txt with cron-run (cron's % rules) for 09:00-12:00 on a
# simulated day: the report line must write report-2025-06-10-{09,10,11}.txt
# with report.sh's output. Other lines and report.sh must be unchanged.
SANDBOX="$1"
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
cd "$SANDBOX" || exit 1

if [ ! -f crontab.txt ]; then
  echo "❌ crontab.txt is missing; type reset to start over"
  exit 1
fi
want_other="$(printf '%s\n' \
  "20 0 * * * tar -czf $SANDBOX/archive/reports-\$(date -d yesterday +\\%F).tgz -C $SANDBOX/reports ." \
  "0 8 * * 1 $SANDBOX/app/notify.sh%Weekly check: are last week's reports complete?" \
  "MAILTO=deploy")"
while IFS= read -r line; do
  if ! grep -Fxq -- "$line" crontab.txt; then
    echo "❌ a line of crontab.txt other than the report job was changed: ${line%% $SANDBOX*} ..."
    exit 1
  fi
done <<< "$want_other"
jobs="$(grep -c 'report\.sh' crontab.txt)"
if [ "$jobs" -ne 1 ]; then
  echo "❌ crontab.txt should have exactly one line that runs report.sh (found $jobs)"
  exit 1
fi
expected_sh='#!/bin/sh
# Hourly sales summary (fixture data instead of the real database query).
echo "Hourly sales report $(date '"'"'+%Y-%m-%d %H:00'"'"')"
echo "orders   37"
echo "revenue  1912.40 EUR"
echo "refunds  2"'
if [ "$(cat app/report.sh 2>/dev/null)" != "$expected_sh" ] || [ ! -x app/report.sh ]; then
  echo "❌ app/report.sh was changed; the fix belongs in the crontab line"
  exit 1
fi

TMP="$(mktemp -d)"
before="$(ls -A reports)"
cleanup() {
  comm -13 <(printf '%s\n' "$before") <(ls -A "$SANDBOX/reports") | while IFS= read -r f; do
    [ -n "$f" ] && rm -rf "${SANDBOX:?}/reports/$f"
  done
  rm -rf "$TMP"
}
trap cleanup EXIT

python3 "$MOCKS/cron/cron-run" --root "$TMP" --crontab "$SANDBOX/crontab.txt:deploy" --no-periodic \
  --from "2025-06-10 09:00" --to "2025-06-10 12:00" --mail-dir "$TMP/mail" -q --jsonl "$TMP/runs.jsonl" > "$TMP/log" 2>&1
if grep -q 'ERROR' "$TMP/log"; then
  echo "❌ cron would ignore crontab.txt: it has a syntax error (cron-run shows it)"
  exit 1
fi
runs="$(python3 -c 'import json,sys
for l in open(sys.argv[1]):
    r = json.loads(l)
    if "report.sh" in r["command"]: print(r["time"], r["exit"], repr(r["output"][:150]))' "$TMP/runs.jsonl")"
if [ "$(printf '%s\n' "$runs" | awk 'NF' | awk '{print $2}' | paste -sd' ' -)" != "09:00 10:00 11:00" ]; then
  echo "❌ between 09:00 and 12:00 the report job ran at: $(printf '%s\n' "$runs" | awk 'NF {print $2}' | paste -sd' ' -); it should run at minute 0 of every hour"
  exit 1
fi
failed="$(printf '%s\n' "$runs" | awk '$3 != 0' | head -n 1)"
if [ -n "$failed" ]; then
  echo "❌ the report job fails under cron (exit $(echo "$failed" | awk '{print $3}')); cron would mail: $(echo "$failed" | cut -d' ' -f4- | tr -d "'" | sed 's/\\n.*//')"
  exit 1
fi
new="$(comm -13 <(printf '%s\n' "$before") <(ls -A reports) | paste -sd' ' -)"
for h in 09 10 11; do
  f="reports/report-2025-06-10-$h.txt"
  if [ ! -f "$f" ]; then
    echo "❌ the 2025-06-10 $h:00 run did not write $f (it created: ${new:-nothing})"
    exit 1
  fi
  if [ "$(head -n 1 "$f")" != "Hourly sales report 2025-06-10 $h:00" ] || [ "$(wc -l < "$f" | tr -d ' ')" != 4 ]; then
    echo "❌ $f does not hold report.sh's output for that hour"
    exit 1
  fi
done
if [ "$(printf '%s\n' "$new" | wc -w | tr -d ' ')" != 3 ]; then
  echo "❌ the three runs created more than the three report files: $new"
  exit 1
fi
echo "✅ each hourly run now writes reports/report-YYYY-MM-DD-HH.txt"
exit 0
