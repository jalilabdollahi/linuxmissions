#!/bin/bash
# Leftover Lock: nightly_export.sh takes a lock, fetches orders into a temp
# dir (a slow step) and converts them to export.csv. When the scheduler kills
# it with TERM, or the converter fails, it leaves export.lock, the temp dir
# and sometimes half an export.csv behind. The next night refuses to start.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p bin

cat > bin/fetch_orders <<'MOCK'
#!/bin/bash
# fetch_orders - stand-in for the slow database query.
# Prints a header and FETCH_ROWS orders (default 300), one every 0.1 s.
echo "order_id|customer|amount"
n="${FETCH_ROWS:-300}"
i=1
while [ "$i" -le "$n" ]; do
  sleep 0.1
  echo "$((40000 + i))|C$((1000 + i * 37 % 211))|$((i * 1379 % 9000)).$((10 + i % 90))"
  i=$((i + 1))
done
MOCK

cat > bin/to_csv <<'MOCK'
#!/bin/bash
# to_csv - turns the pipe-separated query output into CSV.
# With TO_CSV_FAIL_AT=N it gives up after N rows, like it does on a bad row.
n=0
while IFS='|' read -r id cust amount; do
  if [ -n "${TO_CSV_FAIL_AT:-}" ] && [ "$n" -ge "$TO_CSV_FAIL_AT" ]; then
    echo "to_csv: malformed row $((n + 1)): unexpected character" >&2
    exit 1
  fi
  echo "$id,$cust,$amount"
  n=$((n + 1))
done
MOCK
chmod +x bin/fetch_orders bin/to_csv

# Yesterday's good export.
{
  echo "order_id,customer,amount"
  i=1
  while [ $i -le 12 ]; do echo "$((39000 + i)),C$((1000 + i * 41 % 211)),$((i * 977 % 9000)).$((10 + i % 90))"; i=$((i + 1)); done
} > export.csv

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
./bin/fetch_orders > "$work/orders.raw"
./bin/to_csv < "$work/orders.raw" > export.csv
echo "exported $(( $(wc -l < export.csv) - 1 )) orders"

rm -rf "$work"
rm -f export.lock
SCRIPT
chmod +x nightly_export.sh

cat > ONCALL.txt <<'TXT'
01:00  nightly_export.sh started (pid 81723)
01:45  scheduler: job overran its slot, sent SIGTERM to 81723
01:46  ... job still running, scheduler sent SIGKILL
02:00  next run: "export.lock exists, another export is running" -> no export
       /tmp/tmp.Xk2p9QaL1v (2.1 GB of orders.raw) still on disk
Also: on Tuesday to_csv hit a bad row, the job exited 0, and the BI team
loaded a half-written export.csv.

Try it here (fetch_orders takes 30 s; FETCH_ROWS=5 makes it quick):
  ./nightly_export.sh & sleep 1; kill -TERM $!     then:  ls; ls ${TMPDIR:-/tmp}
  FETCH_ROWS=5 TO_CSV_FAIL_AT=3 ./nightly_export.sh; echo $?
TXT
