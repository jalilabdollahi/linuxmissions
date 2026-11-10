#!/bin/bash
# Compress the Old Logs: .log files aged 0 h to 21 days, some with spaces in
# the name, one in a subfolder. The 7.5-day-old logs are "older than 7 days"
# but `-mtime +7` skips them (find drops the fractional day). Old non-.log
# files and an existing .gz must stay untouched.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p app/logs/payments .lm-state
NOW=$(date +%s)
stamp() { date -d "@$1" "$2" 2>/dev/null || date -r "$1" "$2"; }

: > .lm-state/gzip; : > .lm-state/keep
mklog() {  # mklog NAME AGE_MINUTES gzip|keep|none
  local t=$(( NOW - $2 * 60 ))
  awk -v seed="$RANDOM" -v name="$1" 'BEGIN { srand(seed); n = 40 + int(rand() * 200)
    split("INFO INFO INFO WARN ERROR", lv, " ")
    for (i = 1; i <= n; i++) printf "%s line %d req=%06x took %dms\n", lv[1 + int(rand() * 5)], i, int(rand() * 16777215), int(rand() * 900) }' > "$1"
  touch -t "$(stamp "$t" +%Y%m%d%H%M.%S)" "$1"
  [ "$3" = none ] || printf '%s\t%s\t%s\n' "$1" "$(cksum < "$1")" "$2" >> ".lm-state/$3"
}
D=1440
L=app/logs
d() { stamp $(( NOW - $1 * 86400 )) +%Y-%m-%d; }

mklog $L/api.log                          25              keep
mklog "$L/worker 2.log"                   $((3 * D))      keep
mklog $L/api-$(d 6).log                   $((6 * D + 720)) keep
mklog $L/payments/payments-$(d 3).log     $((3 * D + 90)) keep
mklog $L/api-$(d 10).log                  $((10 * D))     gzip
mklog "$L/worker 2-$(d 13).log"           $((13 * D + 60)) gzip
mklog $L/payments/payments-$(d 21).log    $((21 * D))     gzip
mklog $L/api-$(d 7).log                   $((7 * D + 720)) gzip
mklog "$L/worker 2-$(d 7).log"            $((7 * D + 800)) gzip

# Not .log files: must stay exactly as they are, however old.
mklog $L/heap-dump-$(d 20).txt            $((20 * D))     keep
mklog $L/cron.log.1                       $((12 * D))     keep
old=$L/api-$(d 30).log
mklog "$old"                              $((30 * D))     none
gzip "$old"
printf '%s\t%s\t%s\n' "$old.gz" "$(cksum < "$old.gz")" $((30 * D)) >> .lm-state/keep
