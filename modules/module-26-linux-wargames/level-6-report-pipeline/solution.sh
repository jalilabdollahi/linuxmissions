#!/bin/bash
cat > daily_report.sh <<'SH'
#!/bin/bash
# Daily KPI report: ./daily_report.sh YYYY-MM-DD   (mailed to finance at 06:00)
cd "$(dirname "$0")" || exit 1
DAY=${1:?usage: daily_report.sh YYYY-MM-DD}
zcat -f logs/access.log logs/access.log.* |
  grep "^$DAY" |
  awk -v day="$DAY" '$4 == "POST" && $5 == "/checkout" && $6 == 200 && !seen[$3]++ {
        split($7, a, "="); split($8, b, "="); rev += a[2]; n++; u[b[2]] = 1 }
       END { c = 0; for (k in u) c++; printf "date=%s\norders=%d\nrevenue=%.2f\ncustomers=%d\n", day, n, rev, c }'
SH
./daily_report.sh 2026-11-10
