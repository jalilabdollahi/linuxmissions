#!/bin/bash
# The daily sales report "succeeds" under cron but nobody gets anything.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
bash "$MOCKS/cron/install.sh" "$SANDBOX" cron-run cron-expand >/dev/null
mkdir -p .lm logs data opt/tools/bin

cat > opt/tools/bin/salesagg <<'EOF'
#!/bin/bash
# salesagg FILE.csv -- sum orders and revenue (EUR only) per region.
# Rows in another currency are skipped with a warning on stderr.
awk -F, '
  NR == 1 { next }
  $5 != "EUR" { skipped++; next }
  { o[$2] += $3; r[$2] += $4; to += $3; tr += $4 }
  END {
    printf "%-8s %7s %12s\n", "region", "orders", "revenue"
    n = split("EU NA APAC", order, " ")
    for (i = 1; i <= n; i++) if (order[i] in o) printf "%-8s %7d %12.2f\n", order[i], o[order[i]], r[order[i]]
    printf "TOTAL %d %.2f\n", to, tr
    if (skipped) printf "salesagg: warning: skipped %d row(s) with a currency other than EUR\n", skipped > "/dev/stderr"
  }' "$1"
EOF
chmod +x opt/tools/bin/salesagg

cat > report.sh <<'EOF'
#!/bin/bash
# report.sh -- daily sales report for the management mailing list.
# Reads data/sales-YYYY-MM-DD.csv for today and prints the totals.
# Needs the in-house tool salesagg (installed in opt/tools/bin).
here="$(cd "$(dirname "$0")" && pwd)"
day=$(date +%F)
feed="$here/data/sales-$day.csv"
if [ ! -r "$feed" ]; then
  echo "report.sh: no sales feed for $day ($feed)" >&2
  exit 1
fi
echo "SALES REPORT $day"
salesagg "$feed"
EOF
chmod +x report.sh
for f in report.sh opt/tools/bin/salesagg; do
  sha256sum "$f" 2>/dev/null | cut -d' ' -f1 > ".lm/$(basename "$f").sha" || shasum -a 256 "$f" | cut -d' ' -f1 > ".lm/$(basename "$f").sha"
done

mkfeed() {   # mkfeed DAY SEED
  awk -v day="$1" -v seed="$2" 'BEGIN {
    srand(seed); print "date,region,orders,amount,currency"
    split("EU NA APAC EU NA EU APAC NA", rg, " ")
    for (i = 1; i <= 24; i++) {
      cur = (i % 9 == 0) ? "GBP" : "EUR"
      printf "%s,%s,%d,%.2f,%s\n", day, rg[(i % 8) + 1], int(rand() * 40) + 3, rand() * 9000 + 120, cur
    }
  }'
}
mkfeed 2026-11-10 3 > data/sales-2026-11-10.csv
mkfeed 2026-11-11 5 > data/sales-2026-11-11.csv

cat > crontab.txt <<EOF
# user reports -- daily sales report (not installed yet; edit and test here)
MAILTO=root
30 6 * * * $SANDBOX/report.sh 2>&1 > logs/report-\$(date +%F).log
EOF

cat > TICKET.txt <<'EOF'
REP-338  sales report: "runs fine" but nobody gets anything

The management report is supposed to appear every morning at 06:30. Cron says the
job ran (syslog shows it), yet there is no log with the report, the errors we know
the job prints are gone, and nobody was told when the feed was missing last week.

The job line is in crontab.txt. Wanted:
  * everything the job prints (report and error messages) is kept in
    logs/report-YYYY-MM-DD.log, one file per day, in this directory (absolute paths:
    cron does not start where you are)
  * when the job fails, cron mails ops@example.com (and only then: a good run
    stays quiet because its output is in the log)
  * it must work in cron's bare environment (PATH=/usr/bin:/bin). salesagg
    lives in opt/tools/bin: report.sh and salesagg are the developers', don't edit them
bin/cron-run plays cron for a simulated time window; try it on crontab.txt.
EOF
