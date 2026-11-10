#!/bin/bash
SANDBOX="$1"
FILE="$SANDBOX/crontab.txt"

if [ ! -f "$FILE" ]; then
  echo "❌ crontab.txt not found"
  exit 1
fi

# The jobs that were already there must survive.
for line in 'MAILTO=ops@example.com' 'PATH=/usr/local/bin:/usr/bin:/bin' \
            '*/15  *   *   *   *     /opt/myapp/bin/healthcheck >/dev/null 2>&1' \
            '30    2   *   *   0     /usr/local/bin/backup.sh --weekly'; do
  if ! grep -Fxq -- "$line" "$FILE"; then
    echo "❌ an existing line of crontab.txt was changed or removed: $line"
    exit 1
  fi
done

if [ -n "$(tail -c 1 "$FILE")" ]; then
  echo "❌ crontab.txt does not end with a newline; crontab refuses such a file (\"missing newline before EOF\")"
  exit 1
fi

# Active job lines that mention cleanup.sh (skip comments, blanks, VAR=value).
JOBS="$(grep -v '^[[:space:]]*#' "$FILE" | grep -Ev '^[[:space:]]*$|^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=' | grep 'cleanup\.sh')"
count="$(printf '%s' "$JOBS" | grep -c .)"
if [ "$count" -eq 0 ]; then
  echo "❌ crontab.txt has no job that runs cleanup.sh yet"
  exit 1
fi
if [ "$count" -gt 1 ]; then
  echo "❌ crontab.txt has $count jobs for cleanup.sh; keep exactly one"
  exit 1
fi

# expand FIELD MIN MAX KIND -> sorted list of the values cron would match
expand() {
  awk -v f="$1" -v lo="$2" -v hi="$3" -v kind="$4" '
    function val(x,   i) {
      x = tolower(x)
      if (kind == "mon") for (i = 1; i <= 12; i++) if (x == mon[i]) return i
      if (kind == "dow") for (i = 0; i <= 7; i++) if (x == dow[i]) return i
      if (x !~ /^[0-9]+$/) { bad = 1; return lo }
      return x + 0
    }
    BEGIN {
      split("jan feb mar apr may jun jul aug sep oct nov dec", mon, " ")
      split("mon tue wed thu fri sat sun", d, " "); dow[0] = "sun"; for (i = 1; i <= 7; i++) dow[i] = d[i]
      n = split(f, parts, ",")
      for (p = 1; p <= n; p++) {
        item = parts[p]; step = 1
        if (index(item, "/")) { step = substr(item, index(item, "/") + 1); item = substr(item, 1, index(item, "/") - 1)
                                if (step !~ /^[0-9]+$/ || step == 0) bad = 1 }
        if (item == "*") { a = lo; b = hi }
        else if (index(item, "-")) { a = val(substr(item, 1, index(item, "-") - 1)); b = val(substr(item, index(item, "-") + 1)) }
        else { a = val(item); b = (step > 1 ? hi : a) }
        if (a < lo || b > hi || a > b) bad = 1
        for (v = a; v <= b; v += step) { w = (kind == "dow" && v == 7) ? 0 : v; seen[w] = 1 }
      }
      if (bad) { print "BAD"; exit }
      out = ""; for (v = lo; v <= hi; v++) if (v in seen) out = out v " "
      print out
    }'
}

set -f
# shellcheck disable=SC2086
set -- $JOBS
set +f
if [ $# -lt 6 ] || [ "${1#@}" != "$1" ]; then
  echo "❌ the cleanup job needs five time fields (minute hour day-of-month month day-of-week) and then the command"
  exit 1
fi
min="$1"; hour="$2"; dom="$3"; mon="$4"; dow="$5"
CMD="$(printf '%s\n' "$JOBS" | awk '{ for (i = 1; i <= 5; i++) sub(/^[[:space:]]*[^[:space:]]+/, ""); sub(/^[[:space:]]+/, ""); print }')"

for pair in "minute:$min:0:59:num" "hour:$hour:0:23:num" "day-of-month:$dom:1:31:num" "month:$mon:1:12:mon" "day-of-week:$dow:0:7:dow"; do
  IFS=: read -r name f lo hi kind <<< "$pair"
  if [ "$(expand "$f" "$lo" "$hi" "$kind")" = "BAD" ]; then
    echo "❌ the $name field '$f' is not valid cron syntax"
    exit 1
  fi
done

if [ "$(expand "$min" 0 59 num)" != "0 " ] || [ "$(expand "$hour" 0 23 num)" != "3 " ]; then
  echo "❌ the cleanup job does not run at 03:00 (check the minute and hour fields)"
  exit 1
fi
if [ "$(expand "$mon" 1 12 mon)" != "$(expand '*' 1 12 mon)" ]; then
  echo "❌ the cleanup job should run in every month"
  exit 1
fi
if [ "$(expand "$dow" 0 7 dow)" != "1 2 3 4 5 " ]; then
  echo "❌ the day-of-week field does not select exactly Monday to Friday"
  exit 1
fi
case "$dom" in
  '*'|'*/1') ;;
  *) echo "❌ day-of-month must be * here: when both day fields are restricted, cron runs on days matching EITHER one"
     exit 1 ;;
esac

# The command: an absolute path to cleanup.sh, optionally via sh/bash, optionally with redirections.
case "$CMD" in
  *'$'*) echo "❌ the command uses a variable; cron runs with a minimal environment and does not know \$SANDBOX, so write the real absolute path"
         exit 1 ;;
esac
if printf '%s' "$CMD" | grep -q '[^\\]%'; then
  echo "❌ the command contains an unescaped %, which cron turns into a newline"
  exit 1
fi
set -f
# shellcheck disable=SC2086
set -- $CMD
set +f
case "$1" in
  sh|bash|/bin/sh|/bin/bash|/usr/bin/bash|/usr/bin/sh) shift ;;
esac
SCRIPT="$1"
case "$SCRIPT" in
  /*) ;;
  *) echo "❌ the command '$SCRIPT' is not an absolute path; cron starts jobs in your home directory, not here"
     exit 1 ;;
esac
want="$(cd "$SANDBOX" && pwd -P)/cleanup.sh"
got="$(cd "$(dirname "$SCRIPT")" 2>/dev/null && pwd -P)/$(basename "$SCRIPT")"
if [ "$got" != "$want" ]; then
  echo "❌ the job runs $SCRIPT, which is not the cleanup.sh in this sandbox"
  exit 1
fi
shift
for word in "$@"; do
  case "$word" in
    '>'*|'>>'*|'2>'*|'2>>'*|'&>'*|'&>>'*|*'2>&1'|/*|*.log) ;;
    *) echo "❌ unexpected extra text after the script path: $word"
       exit 1 ;;
  esac
done

echo "✅ cleanup.sh is scheduled at 03:00 Monday to Friday and the other jobs are intact"
exit 0
