#!/bin/bash
# report-.txt: "$ENV_$DAY" reads a variable called ENV_, and DAY has no default.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

cat > name-report.sh <<'EOF'
#!/bin/bash
# name-report.sh - writes the daily usage report for one environment.
# Usage:  ENV=staging DAY=2026-11-09 ./name-report.sh
# Cron runs it as plain `ENV=prod ./name-report.sh` (no DAY): then use today.
# Output: reports/report-<ENV>_<DAY>.txt

mkdir -p reports logs
out="reports/report-$ENV_$DAY.txt"
log="logs/$ENV-run.log"

{
  echo "usage report"
  echo "environment: $ENV"
  echo "day: $DAY"
  echo "requests: $(( RANDOM * 7 % 90000 + 10000 ))"
} > "$out"

echo "$(date '+%F %T') wrote $out" >> "$log"
echo "wrote $out"
EOF
chmod +x name-report.sh

# What the broken script left behind so far.
mkdir -p reports logs
printf 'usage report\nenvironment: prod\nday: \nrequests: 48211\n' > reports/report-.txt
printf 'usage report\nenvironment: staging\nday: 2026-11-08\nrequests: 23310\n' > reports/report-2026-11-08.txt
