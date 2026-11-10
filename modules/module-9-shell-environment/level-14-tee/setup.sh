#!/bin/bash
# Three Copies: gen-events taps a (simulated) live event bus and prints logfmt
# lines; every run sees different traffic. The raw stream, the level=error lines
# and their count must all come from the same run. gen-events records each run
# (id and checksum of what it printed) in .gen/runs so the validator can tell.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .gen
: > .gen/runs

cat > gen-events <<'EOF'
#!/bin/bash
# gen-events - tap the checkout event bus for a few seconds and print every
# event that passes by, one logfmt line each. Live traffic: every run differs.
cd "$(dirname "$0")" || exit 1
run=$(printf '%04x%04x' $RANDOM $RANDOM)
svcs=(checkout cart payments search auth)
info_msgs=("request served" "cache hit" "cache miss, fetched from origin"
           "retrying after upstream error" "session refreshed" "health check ok"
           "error budget at 82%" "user logged in")
warn_msgs=("slow query (>500ms)" "queue depth above 1000" "retry 2/3" "deprecated API v1 called")
err_msgs=("payment gateway timeout" "card declined: do not honor" "db connection reset"
          "template render failed" "unhandled exception in /api/cart")
n=$(( 260 + RANDOM % 180 ))
ms=$(( (8 * 3600 + RANDOM % 7200) * 1000 ))
out=""
for (( i = 0; i < n; i++ )); do
  r=$(( RANDOM % 100 ))
  if [ $r -lt 8 ]; then
    lvl=error; msg=${err_msgs[$(( RANDOM % ${#err_msgs[@]} ))]}
  elif [ $r -lt 20 ]; then
    lvl=warn;  msg=${warn_msgs[$(( RANDOM % ${#warn_msgs[@]} ))]}
  else
    lvl=info;  msg=${info_msgs[$(( RANDOM % ${#info_msgs[@]} ))]}
  fi
  ms=$(( ms + RANDOM % 700 ))
  printf -v line '2026-11-10T%02d:%02d:%02d.%03dZ run=%s level=%s svc=%s msg="%s"' \
    $(( ms / 3600000 )) $(( ms / 60000 % 60 )) $(( ms / 1000 % 60 )) $(( ms % 1000 )) \
    "$run" "$lvl" "${svcs[$(( RANDOM % ${#svcs[@]} ))]}" "$msg"
  out+="$line"$'\n'
done
# Stream it out in bursts, like the bus does.
printf '%s' "$out" | while IFS= read -r line; do
  printf '%s\n' "$line"
  [ $(( RANDOM % 60 )) -eq 0 ] && sleep 0.2
done
printf '%s %s\n' "$run" "$(printf '%s' "$out" | cksum | tr ' ' ':')" >> .gen/runs
EOF
chmod +x gen-events

cat > INCIDENT.txt <<'EOF'
INC-2207  checkout errors spiking
---------------------------------
Please attach a snapshot of the event bus to the incident:
  events.raw       everything gen-events printed, unchanged
  errors.log       only the events whose level is error
  error_count.txt  how many of those there were (just the number)
All three must describe the SAME capture. gen-events shows live traffic,
so two runs never print the same events.
EOF
