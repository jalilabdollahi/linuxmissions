#!/bin/bash
# Compares report.txt with the hidden behaviour of each host, then checks in
# healthcheck.sh's own run log that every hanging check was stopped about 3 s
# after it started and that no check is still running.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -f report.txt ]; then
  echo "❌ report.txt not found"
  exit 1
fi

want=$(awk '{ s = ($2 == "ok" || $2 == "slow") ? "OK" : ($2 == "hang" || $2 == "stubborn") ? "TIMEOUT" : "FAIL"; print $1, s }' .lm/fleet)
got=$(sed -e 's/\r$//' -e 's/[[:space:]]*$//' -e 's/[[:space:]][[:space:]]*/ /g' report.txt)
nwant=$(printf '%s\n' "$want" | wc -l | tr -d ' ')
ngot=$(printf '%s\n' "$got" | grep -c .)
if [ "$ngot" -ne "$nwant" ]; then
  echo "❌ report.txt has $ngot lines; hosts.txt has $nwant hosts"
  exit 1
fi
i=0
while IFS=' ' read -r host status; do
  i=$((i + 1))
  line=$(printf '%s\n' "$got" | sed -n "${i}p")
  ghost=${line%% *}
  gstat=${line#* }
  if [ "$ghost" != "$host" ]; then
    echo "❌ line $i of report.txt is about '$ghost'; line $i of hosts.txt is $host (keep the order of hosts.txt)"
    exit 1
  fi
  case "$gstat" in OK|FAIL|TIMEOUT) ;; *)
    echo "❌ line $i of report.txt: status '$gstat' is not OK, FAIL or TIMEOUT"
    exit 1 ;;
  esac
  if [ "$gstat" != "$status" ]; then
    mode=$(awk -v h="$host" '$1 == h { print $2 }' .lm/fleet)
    case "$gstat/$mode" in
      TIMEOUT/slow) echo "❌ $host is reported TIMEOUT, but it answers within 3 seconds (just not instantly)" ;;
      FAIL/stubborn|OK/stubborn) echo "❌ $host is reported $gstat, but its check never answered; look at the exit status you got for it" ;;
      FAIL/hang|OK/hang) echo "❌ $host is reported $gstat, but its check never answered" ;;
      TIMEOUT/*) echo "❌ $host is reported TIMEOUT, but its check returned quickly" ;;
      *) echo "❌ $host is reported $gstat, which is not what its check returned" ;;
    esac
    exit 1
  fi
done <<< "$want"

# Every host must really have been checked, and every hanging check must have
# been stopped 3 s (give or take) after it started.
while IFS=' ' read -r host mode; do
  if ! grep -q "^start $host " .lm/runs 2>/dev/null; then
    echo "❌ healthcheck.sh was never run for $host"
    exit 1
  fi
  case "$mode" in hang|stubborn) ;; *) continue ;; esac
  verdict=$(awk -v h="$host" '
    $1 == "start" && $2 == h { t[$3] = $4 }
    $1 == "term" && $2 == h && ($3 in t) { d = $4 - t[$3]; if (d >= 2.5 && d <= 4) ok = 1; else last = d }
    END { if (ok) print "ok"; else if (last != "") printf "%.1f\n", last; else print "never" }' .lm/runs)
  case "$verdict" in
    ok) ;;
    never) echo "❌ the check of $host was never stopped with a signal; limit each check to 3 seconds"; exit 1 ;;
    *) echo "❌ the check of $host was stopped after ${verdict}s, not after 3 seconds"; exit 1 ;;
  esac
done < .lm/fleet

left=""
for pid in $(awk '$1 == "start" { print $3 }' .lm/runs); do
  if kill -0 "$pid" 2>/dev/null && tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | grep -q healthcheck; then
    left="$left $pid"
  fi
done
if [ -n "$left" ]; then
  echo "❌ healthcheck.sh is still running (PID$left); a stopped check must not leave processes behind"
  exit 1
fi

echo "✅ report.txt matches every host, and each hanging check was cut off after 3 seconds"
exit 0
