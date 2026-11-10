#!/bin/bash
# heavy.txt = "PID COMMAND..." for user www-data with %MEM > 5;
# stuck.txt = "PID COMMAND..." for every process whose STAT starts with D or Z.
# Both in snapshot order, full command lines; runs of blanks are ignored.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/ps.sum ] || [ "$(cksum < ps-aux.txt 2>/dev/null)" != "$(cat .lm-state/ps.sum)" ]; then
  echo "❌ ps-aux.txt was changed or removed; type 'reset' to restore it"
  exit 1
fi

pick() { awk "NR > 1 && ($1) { out = \$2; for (i = 11; i <= NF; i++) out = out \" \" \$i; print out }" ps-aux.txt; }
norm() { tr -d '\r' < "$1" | awk 'NF { $1 = $1; print }'; }
pids_of() { awk "NR > 1 && ($1) { print \$2 }" ps-aux.txt; }

check() {  # check FILE CONDITION WHAT
  local f=$1 cond=$2 what=$3 want got w g extra
  if [ ! -f "$f" ]; then echo "❌ $f does not exist yet"; return 1; fi
  want=$(pick "$cond"); got=$(norm "$f")
  [ "$got" = "$want" ] && return 0
  if [ -z "$got" ]; then echo "❌ $f is empty"; return 1; fi
  if printf '%s\n' "$got" | grep -q 'PID\|COMMAND'; then
    echo "❌ $f contains the header line of the ps output"; return 1
  fi
  if printf '%s\n' "$got" | awk '$1 !~ /^[0-9]+$/ { f = 1 } END { exit !f }'; then
    echo "❌ every line of $f must start with the PID, then the command"; return 1
  fi
  w=$(printf '%s\n' "$want" | wc -l | tr -d ' ')
  g=$(printf '%s\n' "$got" | wc -l | tr -d ' ')
  # same PIDs but shorter lines: the command was cut at the first blank
  if [ "$(printf '%s\n' "$got" | awk '{ print $1 }')" = "$(printf '%s\n' "$want" | awk '{ print $1 }')" ]; then
    if printf '%s\n' "$got" | awk '{ print NF }' | paste -d' ' - <(printf '%s\n' "$want" | awk '{ print NF }') | awk '$1 < $2 { f = 1 } END { exit !f }'; then
      echo "❌ $f has the right processes, but commands are cut off after the first word: COMMAND is field 11 up to the last field (NF)"
    else
      echo "❌ $f has the right processes, but the lines are not 'PID command' exactly as ps printed the command"
    fi
    return 1
  fi
  extra=$(printf '%s\n' "$got" | awk '{ print $1 }' | sort | comm -23 - <(printf '%s\n' "$want" | awk '{ print $1 }' | sort) | head -1)
  if [ -n "$extra" ]; then
    awk -v p="$extra" -v f="$f" -v what="$what" 'NR > 1 && $2 == p {
      if ($1 == "www-dep+") print "❌ " f " has PID " p " of user www-dep+: ps cuts long user names (this is www-deploy), compare the whole field with == \"www-data\""
      else if ($1 != "www-data" && what == "heavy") print "❌ " f " has PID " p ", which belongs to " $1 " (www-data only appears in its command line)"
      else if (what == "heavy" && $4 + 0 <= 5) print "❌ " f " has PID " p " with %MEM " $4 ": only more than 5% counts"
      else print "❌ " f " has PID " p " (" $1 ", STAT " $8 "), which does not belong in it"
      exit }' ps-aux.txt
    return 1
  fi
  if [ "$g" -lt "$w" ]; then
    if [ "$what" = stuck ]; then
      echo "❌ $f has $g of the $w processes in state D or Z: STAT often carries extra flags (Ds, D<, Z+), so match the first letter"
    else
      echo "❌ $f has $g of the $w www-data processes using more than 5% memory"
    fi
    return 1
  fi
  echo "❌ $f has the right processes but not in the order of ps-aux.txt"
  return 1
}

check heavy.txt '$1 == "www-data" && $4 > 5' heavy || exit 1
check stuck.txt '$8 ~ /^[DZ]/' stuck || exit 1
echo "✅ heavy.txt lists $(grep -c . heavy.txt) memory-hungry www-data processes, stuck.txt $(grep -c . stuck.txt) processes in D or Z state"
exit 0
