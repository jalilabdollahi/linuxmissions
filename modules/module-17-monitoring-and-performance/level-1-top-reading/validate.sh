#!/bin/bash
# summary.env must hold the five values of this top.txt.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/want ] || [ ! -s top.txt ]; then
  echo "❌ the level's data is gone; type 'reset'"
  exit 1
fi
. .lm-state/want
getv() { sed -n "s/^$1=//p" summary.env 2>/dev/null | tail -1 | tr -d ' "%\r'; }

for k in LOAD1 LOAD15 IOWAIT ZOMBIES TOP_MEM_PID; do
  if [ -z "$(getv $k)" ]; then
    echo "❌ $k is still empty in summary.env"
    exit 1
  fi
done
if [ "$(getv LOAD1)" != "$LOAD1" ]; then
  echo "❌ LOAD1 is '$(getv LOAD1)': it is the first of the three numbers after 'load average:' (1, 5 and 15 minutes)"
  exit 1
fi
if [ "$(getv LOAD15)" != "$LOAD15" ]; then
  echo "❌ LOAD15 is '$(getv LOAD15)': it is the last of the three load numbers, not the first or the middle one"
  exit 1
fi
if [ "$(getv IOWAIT)" != "$IOWAIT" ]; then
  echo "❌ IOWAIT is '$(getv IOWAIT)', which is not the wa figure on the %Cpu(s) line of top.txt"
  exit 1
fi
if [ "$(getv ZOMBIES)" != "$ZOMBIES" ]; then
  echo "❌ ZOMBIES is '$(getv ZOMBIES)': take the zombie count from the Tasks line"
  exit 1
fi
got=$(getv TOP_MEM_PID)
if [ "$got" = "$WRONG_PID" ]; then
  echo "❌ TOP_MEM_PID $got has the biggest number in the RES column, but RES mixes KiB, m (MiB) and g (GiB); compare them in one unit"
  exit 1
fi
if [ "$got" != "$TOP_MEM_PID" ]; then
  echo "❌ TOP_MEM_PID $got is not the process with the largest resident memory (RES) in top.txt"
  exit 1
fi
echo "✅ summary.env matches the capture: load $LOAD1/$LOAD15, ${IOWAIT}% iowait, $ZOMBIES zombie(s), biggest RES is PID $TOP_MEM_PID"
exit 0
