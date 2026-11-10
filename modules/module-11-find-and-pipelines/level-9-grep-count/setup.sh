#!/bin/bash
# The Noisiest Services: 30 logs with a random number of ERROR lines each.
# Traps near the threshold: exactly 50 (not more), 51, logs that only pass 50
# when NOERROR / ERRORS_RESET / lowercase "error" are counted too, and ERROR
# lines that say ERROR twice (counting occurrences overshoots).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p logs .lm-state

svcs="api-gateway auth billing cart catalog checkout coupons dns-cache email
feature-flags fraud geo images inventory invoices ledger notifications orders
payments pricing profile ratings recommendations refunds search sessions
shipping tax uploads webhooks"
set -- $(printf '%s\n' $svcs | awk -v seed="$RANDOM" 'BEGIN { srand(seed) } { print rand() "\t" $0 }' | sort -n | cut -f2)

# errors noerror errors_reset double_error_lines lowercase_error
gen() {
  awk -v seed="$RANDOM" -v svc="$1" -v err="$2" -v noerr="$3" -v reset="$4" -v dbl="$5" -v lower="$6" '
  BEGIN {
    srand(seed); n = 0
    for (i = 0; i < err; i++)   ev[n++] = (i < dbl) ? "ERROR upstream returned ERROR " (500 + int(rand() * 4)) : "ERROR request failed: " (rand() < 0.5 ? "timeout after 30s" : "connection refused")
    for (i = 0; i < noerr; i++) ev[n++] = "INFO dns lookup db.internal rcode=NOERROR " int(rand() * 9) "ms"
    for (i = 0; i < reset; i++) ev[n++] = "INFO metrics flushed, ERRORS_RESET=" int(rand() * 40)
    for (i = 0; i < lower; i++) ev[n++] = "WARN retrying, last error was transient"
    m = 300 + int(rand() * 500)
    for (i = 0; i < m; i++) { r = rand()
      ev[n++] = (r < 0.65) ? "INFO handled request in " int(rand() * 300) "ms" : (r < 0.85) ? "DEBUG cache hit ratio " int(rand() * 100) "%" : "WARN slow query " int(rand() * 3000) "ms" }
    for (i = n - 1; i > 0; i--) { j = int(rand() * (i + 1)); t = ev[i]; ev[i] = ev[j]; ev[j] = t }
    for (i = 0; i < n; i++) {
      split(ev[i], w, " "); lvl = w[1]; msg = substr(ev[i], length(lvl) + 2)
      s = int(i * 86000 / n)
      printf "2026-11-10T%02d:%02d:%02d.%03dZ %s [%s] %s\n", s / 3600, (s / 60) % 60, s % 60, int(rand() * 1000), lvl, svc, msg
    }
  }' > "logs/$1.log"
  echo "$1.log $2" >> .lm-state/counts
}

: > .lm-state/counts
gen "$1"  50  14 0  0  6     # exactly 50: not "more than 50"
gen "$2"  51  0  0  0  0
gen "$3"  44  19 0  0  0     # 63 with NOERROR
gen "$4"  47  0  9  0  3     # 56 with ERRORS_RESET
gen "$5"  33  0  0 33  0     # 66 occurrences, 33 lines
gen "$6"  28  0  0  0 40     # 68 with grep -i
shift 6
# The others: distinct random counts, about one in four above 50.
for s in "$@"; do
  while :; do
    if [ $(( RANDOM % 4 )) -eq 0 ]; then c=$(( 52 + RANDOM % 90 )); else c=$(( RANDOM % 49 )); fi
    grep -q " $c\$" .lm-state/counts || break
  done
  gen "$s" "$c" $(( RANDOM % 4 )) $(( RANDOM % 3 )) $(( RANDOM % 5 )) $(( RANDOM % 6 ))
done
awk '$2 > 50' .lm-state/counts | sort -k2,2nr > .lm-state/noisy
cksum logs/*.log | cksum > .lm-state/logs.sum
