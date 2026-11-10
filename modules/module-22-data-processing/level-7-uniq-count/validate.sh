#!/bin/bash
# longest_outage.txt = "<first DOWN timestamp> <length>" of the longest run of
# consecutive DOWN lines (any error text).
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/probe.sum ] || [ "$(cksum < probe.log 2>/dev/null)" != "$(cat .lm-state/probe.sum)" ]; then
  echo "❌ probe.log was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f longest_outage.txt ]; then
  echo "❌ longest_outage.txt does not exist yet"
  exit 1
fi

EXPECTED=$(awk '$2 == "DOWN" { if (!run) at = $1; if (++run > best) { best = run; bat = at } next } { run = 0 }
  END { print bat, best }' probe.log)
GOT=$(tr -d '\r' < longest_outage.txt | sed '/^[[:space:]]*$/d' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/[[:space:]][[:space:]]*/ /g')
if [ "$GOT" = "$EXPECTED" ]; then
  echo "✅ longest_outage.txt: the longest outage started at ${EXPECTED% *} and lasted ${EXPECTED#* } minutes"
  exit 0
fi

if [ -z "$GOT" ]; then echo "❌ longest_outage.txt is empty"; exit 1; fi
if [ "$(printf '%s\n' "$GOT" | wc -l)" -ne 1 ]; then
  echo "❌ longest_outage.txt must have exactly one line"
  exit 1
fi
ts=${GOT%% *}; n=${GOT##* }
if ! printf '%s\n' "$GOT" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z [0-9]+$'; then
  echo "❌ write one line: the timestamp as probe.log writes it, a space, and the number of minutes (e.g. 2026-11-09T13:42:00Z 17)"
  exit 1
fi
want_ts=${EXPECTED% *}; want_n=${EXPECTED#* }
total=$(awk '$2 == "DOWN"' probe.log | wc -l | tr -d ' ')
by_error=$(awk '{ k = $2 " " ($2 == "DOWN" ? $3 : "") } $2 == "DOWN" { if (k != prev) run = 0; if (++run > b) b = run } { prev = k } $2 != "DOWN" { run = 0 } END { print b }' probe.log)
if [ "$n" = "$total" ]; then
  echo "❌ $n is the number of DOWN minutes in the whole day; only consecutive DOWN probes form one outage"
elif [ "$n" = "$by_error" ] && [ "$n" != "$want_n" ]; then
  echo "❌ $n minutes is the longest stretch with the same error; an outage goes on while the probe says DOWN, whatever the error"
elif [ "$ts" = "$want_ts" ]; then
  echo "❌ the start time is right, but the outage did not last $n minutes; count every DOWN probe up to the next UP"
elif [ "$n" = "$want_n" ]; then
  if grep -q "^$ts DOWN" probe.log; then
    echo "❌ the length is right, but $ts is not the first DOWN probe of that outage"
  else
    echo "❌ the length is right, but the timestamp must be the first DOWN probe of that outage"
  fi
else
  echo "❌ that is not the longest run of consecutive DOWN probes"
fi
exit 1
