#!/bin/bash
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/want ] || [ ! -s vmstat.txt ]; then echo "❌ the level's data is gone; type 'reset'"; exit 1; fi
. .lm-state/want
getv() { sed -n "s/^$1=//p" answers.env 2>/dev/null | tail -1 | tr -d ' "\r'; }
f=$(getv FIRST_SWAP_SAMPLE); h=$(getv HIGH_IOWAIT_SAMPLES)
[ -n "$f" ] || { echo "❌ FIRST_SWAP_SAMPLE is still empty in answers.env"; exit 1; }
[ -n "$h" ] || { echo "❌ HIGH_IOWAIT_SAMPLES is still empty in answers.env"; exit 1; }
case "$f$h" in *[!0-9]*) echo "❌ answers.env values must be plain numbers"; exit 1;; esac

if [ "$f" != "$FIRST" ]; then
  if [ "$f" -gt "$FIRST" ] && [ $((f - FIRST)) -le 6 ]; then
    echo "❌ FIRST_SWAP_SAMPLE $f is a few too high: header lines are not samples, so sample numbers must skip them"
  elif [ "$f" -lt 4 ]; then
    echo "❌ FIRST_SWAP_SAMPLE $f is too early: swpd (swap in use) was already non-zero before the problem; look at the swap-rate columns si and so"
  else
    echo "❌ FIRST_SWAP_SAMPLE $f is not the first sample with swap traffic (non-zero si or so)"
  fi
  exit 1
fi
if [ "$h" != "$HIGH" ]; then
  if [ "$h" -gt "$HIGH" ] && [ "$h" -le $((HIGH + 6)) ]; then
    echo "❌ HIGH_IOWAIT_SAMPLES $h is too high: only values strictly above 30 count (30 itself does not), and header lines are not samples"
  else
    echo "❌ HIGH_IOWAIT_SAMPLES $h is wrong: count the samples whose wa column is above 30"
  fi
  exit 1
fi
echo "✅ swapping began at sample $FIRST and $HIGH samples had iowait above 30"
exit 0
