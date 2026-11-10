#!/bin/bash
# $1 = sandbox path
# data/ as it is on Sunday evening, and simulate-day.sh, which plays the week:
#   mon: new orders file, one customer changed, one customer deleted
#   tue: new orders file, a report moved into a new dir, the import cache dir removed
#   wed: new orders file, new customer, oldest orders file deleted, a customer changed
#   thu: the data disk dies (data/ is gone)
# Each day refuses to start before the previous day's backup exists, and thu
# records a fingerprint of Wednesday's final state for the validator.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

mkdir -p data/customers data/orders data/static data/reports data/tmp/import-cache backups .simulate
for c in 1001 1002 1003 1004 1005 1006 1007 1008; do
  printf '{ "id": %d, "name": "customer-%d", "credit": %d }\n' "$c" "$c" $((RANDOM % 5000)) > "data/customers/c-$c.json"
done
{
  echo "order_id,customer,total"
  for i in $(seq 1 40); do echo "$((90000 + RANDOM % 9999)),$((1001 + RANDOM % 8)),$((RANDOM % 400)).$((RANDOM % 90 + 10))"; done
} > data/orders/2026-11-08.csv
head -c 6144 /dev/urandom > data/static/logo.png
head -c 9000 /dev/urandom > data/static/terms.pdf
printf 'week 45: %d orders, %d returns\n' $((RANDOM % 900)) $((RANDOM % 40)) > data/reports/weekly.txt
for i in 1 2 3; do head -c 2048 /dev/urandom > "data/tmp/import-cache/batch-$i.tmp"; done
echo sun > .simulate/day

cat > simulate-day.sh <<'SIM'
#!/bin/bash
# Plays one day of changes in data/:  ./simulate-day.sh mon|tue|wed|thu
cd "$(dirname "$0")" || exit 1
today=$(cat .simulate/day 2>/dev/null || echo sun)
want=$1
case "$today:$want" in
  sun:mon) prev=sun ;;
  mon:tue) prev=mon ;;
  tue:wed) prev=tue ;;
  wed:thu) prev=wed ;;
  *)
    case $today in
      sun) next=mon ;; mon) next=tue ;; tue) next=wed ;; wed) next=thu ;;
      *)   next="nothing (type reset to replay the week)" ;;
    esac
    echo "simulate-day: today is $today; the next day to play is $next"
    exit 1 ;;
esac
if [ ! -f "backups/data-$prev.tar.gz" ]; then
  echo "simulate-day: the nightly job found no backups/data-$prev.tar.gz; take that backup before the next day starts"
  exit 1
fi
orders() {
  echo "order_id,customer,total"
  for i in $(seq 1 $((RANDOM % 20 + 25))); do echo "$((90000 + RANDOM % 9999)),$((1001 + RANDOM % 9)),$((RANDOM % 400)).$((RANDOM % 90 + 10))"; done
}
case $want in
  mon)
    orders > data/orders/2026-11-09.csv
    printf '{ "id": 1003, "name": "customer-1003", "credit": %d, "vip": true }\n' $((RANDOM % 5000)) > data/customers/c-1003.json
    rm data/customers/c-1005.json
    echo "Monday: new orders, customer 1003 updated, customer 1005 deleted (GDPR request)" ;;
  tue)
    orders > data/orders/2026-11-10.csv
    mkdir -p data/reports/archive
    mv data/reports/weekly.txt data/reports/archive/weekly-45.txt
    printf '{ "id": 1001, "name": "customer-1001", "credit": %d }\n' $((RANDOM % 5000)) > data/customers/c-1001.json
    rm -r data/tmp/import-cache
    echo "Tuesday: new orders, weekly report moved to reports/archive/, customer 1001 updated, import cache removed" ;;
  wed)
    orders > data/orders/2026-11-11.csv
    printf '{ "id": 1009, "name": "customer-1009", "credit": %d }\n' $((RANDOM % 5000)) > data/customers/c-1009.json
    rm data/orders/2026-11-08.csv
    printf '{ "id": 1003, "name": "customer-1003", "credit": %d, "vip": false }\n' $((RANDOM % 5000)) > data/customers/c-1003.json
    echo "Wednesday: new orders, new customer 1009, orders of 11-08 purged, customer 1003 updated" ;;
  thu)
    ( cd data && find . -print | LC_ALL=C sort | while IFS= read -r p; do
        if [ -f "$p" ]; then echo "f $p $(cksum < "$p")"; else echo "d $p"; fi
      done ) > .simulate/wed.state
    rm -rf data
    echo "Thursday 03:12: the data disk failed. data/ is gone. Restore Wednesday's state from backups/." ;;
esac
echo "$want" > .simulate/day
SIM
chmod +x simulate-day.sh

cat > BACKUP-PLAN.txt <<'EOF'
data/ backup plan (GNU tar, snapshot file in backups/):
  Sunday     full backup          backups/data-sun.tar.gz   (level 0)
  Mon-Wed    incremental backups  backups/data-mon.tar.gz, data-tue.tar.gz, data-wed.tar.gz
Each nightly archive holds only what changed, and GNU tar records the
directory listings so that deletions can be replayed on restore.
It is Sunday evening now. ./simulate-day.sh mon|tue|wed|thu plays the next day.
EOF
