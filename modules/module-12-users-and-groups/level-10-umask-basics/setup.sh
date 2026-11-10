#!/bin/bash
# The weekly report job: publish.sh writes a report tree into the shared project
# dir, but teammates (same group, different user) cannot edit what it creates,
# because the job runs with the default umask 022 and files come out 644, dirs
# 755. The fix is a umask in the script. Traps: umask after the first mkdir, a
# subshell `( umask 002 )` that has already exited, a chmod afterwards (forbidden).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p data shared

# three days of access logs; counts and 5xx lines differ on every run
for day in mon tue wed; do
  awk -v seed="$RANDOM" -v day="$day" 'BEGIN {
    srand(seed); n = 60 + int(rand() * 60)
    split("200 200 200 200 301 404 500 502 503", st, " ")
    split("/ /login /api/items /api/orders /static/app.js /health /report", p, " ")
    for (i = 1; i <= n; i++)
      printf "10.0.%d.%d - - [%s/Nov/2026:%02d:%02d:%02d +0000] \"GET %s HTTP/1.1\" %s %d\n", \
        int(rand() * 4), 1 + int(rand() * 250), day, int(rand() * 24), int(rand() * 60), int(rand() * 60), \
        p[1 + int(rand() * 7)], st[1 + int(rand() * 9)], 100 + int(rand() * 9000)
  }' > "data/access-$day.log"
done

cat > publish.sh <<'EOT'
#!/bin/bash
# publish.sh - build this week's report in the shared project directory.
# Usage: ./publish.sh [output-dir]      (default: shared/reports)
# Run by cron as "reports"; the team (group "analytics") edits the results.
cd "$(dirname "$0")" || exit 1
OUT=${1:-shared/reports}
WEEK=2026-w45

mkdir -p "$OUT/$WEEK/raw"

total=$(cat data/*.log | wc -l)
errors=$(awk '$9 ~ /^5/' data/*.log | wc -l)
cat > "$OUT/$WEEK/summary.txt" <<ENDREPORT
Weekly report $WEEK
total requests: $total
server errors: $errors
ENDREPORT

for f in data/access-*.log; do
  name=$(basename "$f" .log)
  sort "$f" > "$OUT/$WEEK/raw/${name#access-}.sorted"
done

echo "$WEEK published" >> "$OUT/publish.log"
EOT
chmod 755 publish.sh
echo "Shared project directory for the analytics team (group analytics, setgid)." > shared/README
