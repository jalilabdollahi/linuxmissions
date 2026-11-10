#!/bin/bash
# Brace the variable names and give DAY a default.
cat > name-report.sh <<'EOF'
#!/bin/bash
# name-report.sh - writes the daily usage report for one environment.
# Usage:  ENV=staging DAY=2026-11-09 ./name-report.sh
# Cron runs it as plain `ENV=prod ./name-report.sh` (no DAY): then use today.
# Output: reports/report-<ENV>_<DAY>.txt

DAY="${DAY:-$(date +%F)}"
mkdir -p reports logs
out="reports/report-${ENV}_${DAY}.txt"
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
ENV=staging ./name-report.sh
