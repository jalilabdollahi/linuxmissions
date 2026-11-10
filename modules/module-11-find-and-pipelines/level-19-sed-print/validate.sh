#!/bin/bash
# db-section.txt = from the "[database]" header up to (not including) the next
# header; trailing empty lines don't matter. excerpt.txt = lines 1200-1260
# of trace.log, both included.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/inputs.sum ] || [ "$(cat app.ini trace.log 2>/dev/null | cksum)" != "$(cat .lm-state/inputs.sum)" ]; then
  echo "❌ app.ini or trace.log was changed or removed; type 'reset' to restore them"
  exit 1
fi
# drop CRs and trailing empty lines
trim() { tr -d '\r' < "$1" | awk 'NF { for (; blank > 0; blank--) print ""; print; next } { blank++ }'; }

if [ ! -f db-section.txt ]; then
  echo "❌ db-section.txt does not exist yet"
  exit 1
fi
WANT=$(awk '$0 == "[database]" { on = 1; print; next } on && /^\[/ { exit } on' app.ini | awk 'NF { for (; b > 0; b--) print ""; print; next } { b++ }')
GOT=$(trim db-section.txt)
if [ "$GOT" != "$WANT" ]; then
  first=$(printf '%s\n' "$GOT" | head -1)
  last=$(printf '%s\n' "$GOT" | tail -1)
  if [ -z "$GOT" ]; then
    echo "❌ db-section.txt is empty"
  elif [ "$(printf '%s\n' "$GOT" | wc -l)" -gt 30 ]; then
    echo "❌ db-section.txt has $(printf '%s\n' "$GOT" | wc -l | tr -d ' ') lines, far more than one section: unescaped, [database] is a bracket expression that matches any line containing one of the letters d a t b s e"
  elif printf '%s\n' "$GOT" | grep -q -e '^\[database-replica\]' -e 'used by the reporting jobs'; then
    echo "❌ db-section.txt starts too early (at the replica section or its comment that mentions [database]): anchor the pattern to the whole header line"
  elif [ "$last" = "[cache]" ]; then
    echo "❌ db-section.txt ends with the next header, [cache]: the range includes the line that ends it, so drop that line"
  elif [ "$first" != "[database]" ]; then
    echo "❌ db-section.txt must start with the [database] header line"
  else
    echo "❌ db-section.txt must hold every line of the [database] section, from its header to the line before the next header, unchanged"
  fi
  exit 1
fi

if [ ! -f excerpt.txt ]; then
  echo "❌ db-section.txt is right; excerpt.txt does not exist yet"
  exit 1
fi
if tr -d '\r' < excerpt.txt | cmp -s - <(sed -n '1200,1260p' trace.log); then
  echo "✅ db-section.txt and excerpt.txt (lines 1200-1260) are ready for the vendor"
  exit 0
fi
n=$(grep -c '' excerpt.txt)
first=$(head -1 excerpt.txt | tr -d '\r')
at=$(grep -nxF -m1 -- "$first" trace.log | cut -d: -f1)
if [ "$n" -eq 60 ]; then
  echo "❌ excerpt.txt has 60 lines; 1200 to 1260 with both ends included is 61"
elif [ "$n" -ne 61 ]; then
  echo "❌ excerpt.txt has $n lines; lines 1200 to 1260 are 61 lines"
elif [ -n "$at" ] && [ "$at" -ne 1200 ]; then
  echo "❌ excerpt.txt starts at line $at of trace.log instead of line 1200"
else
  echo "❌ excerpt.txt has 61 lines, but they are not lines 1200-1260 of trace.log exactly"
fi
exit 1
