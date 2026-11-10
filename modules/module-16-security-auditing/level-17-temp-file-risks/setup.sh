#!/bin/bash
# nightly-report.sh writes its work file to $TMPDIR/report.tmp (a fixed, guessable name),
# deletes it only on the last line, and uses set -e, so a failing data check leaves it behind.
# data/sales.csv is random (customer names and amounts differ per run). The report the
# original script produces for it is stored for the validator.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
rm -rf data nightly-report.sh .lm-state; mkdir -p data .lm-state

names=(acme globex initech umbrella hooli stark wayne wonka soylent tyrell)
{
  echo "id,customer,amount"
  n=$((12 + RANDOM % 8))
  for i in $(seq 1 "$n"); do
    printf '%d,%s,%d.%02d\n' $((1000 + i)) "${names[RANDOM % ${#names[@]}]}" $((20 + RANDOM % 900)) $((RANDOM % 100))
  done
} > data/sales.csv

cat > nightly-report.sh <<'SCRIPT'
#!/bin/bash
# nightly-report.sh DATA.csv OUT.txt  --  order count, total and top customers
set -e
data=$1
out=$2
tmp=${TMPDIR:-/tmp}/report.tmp

echo "NIGHTLY REPORT" > "$tmp"
echo "source: $(basename "$data")" >> "$tmp"
check_data() { awk -F, 'NF != 3 { exit 2 }' "$data"; }
check_data
awk -F, 'NR > 1 { n++; t += $3 } END { printf "orders: %d\ntotal: %.2f\n", n, t }' "$data" >> "$tmp"
echo "top customers:" >> "$tmp"
tail -n +2 "$data" | sort -t, -k3 -nr | head -3 | awk -F, '{ printf "  %s %.2f\n", $2, $3 }' >> "$tmp"
cp "$tmp" "$out"
rm -f "$tmp"
SCRIPT
chmod 755 nightly-report.sh
t=$(mktemp -d) || exit 1
TMPDIR=$t bash nightly-report.sh data/sales.csv .lm-state/expected-report || exit 1
rm -rf "$t"
sha256sum < data/sales.csv > .lm-state/data.sha
