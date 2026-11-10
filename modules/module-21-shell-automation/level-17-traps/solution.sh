#!/bin/bash
# Reference solution: an EXIT trap installed once the lock is ours, a TERM
# trap that exits 143, the slow step in the background with wait (so the trap
# runs at once), and the CSV written to the temp dir first, then moved.
cat > nightly_export.sh <<'SCRIPT'
#!/bin/bash
# nightly_export.sh - export today's orders to export.csv
# Runs from cron at 01:00. The scheduler sends SIGTERM when the job overruns.
if [ -e export.lock ]; then
  echo "nightly_export: export.lock exists, another export is running" >&2
  exit 1
fi
echo $$ > export.lock

work=$(mktemp -d)
fetch_pid=""
cleanup() {
  if [ -n "$fetch_pid" ]; then kill "$fetch_pid" 2>/dev/null; fi
  rm -rf "$work"
  rm -f export.lock
}
trap cleanup EXIT
trap 'exit 143' TERM
trap 'exit 130' INT

./bin/fetch_orders > "$work/orders.raw" &
fetch_pid=$!
wait "$fetch_pid" || { echo "nightly_export: fetch_orders failed" >&2; exit 1; }
fetch_pid=""

./bin/to_csv < "$work/orders.raw" > "$work/export.csv" || { echo "nightly_export: to_csv failed" >&2; exit 1; }
mv "$work/export.csv" export.csv
echo "exported $(( $(wc -l < export.csv) - 1 )) orders"
SCRIPT
FETCH_ROWS=5 ./nightly_export.sh
