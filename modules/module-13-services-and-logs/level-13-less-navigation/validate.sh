#!/bin/bash
# trace.txt = the trace id on the line two above the first "panic: " line
# after the second real "deploy finished: " marker. Computed from huge.log.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -f huge.log ] || [ "$(cksum < huge.log)" != "$(cat .lm-state/huge.sum 2>/dev/null)" ]; then
  echo "❌ huge.log was changed or removed; type 'reset' to get the original back"
  exit 1
fi
if [ ! -f trace.txt ]; then
  echo "❌ trace.txt does not exist yet"
  exit 1
fi

# One pass: for the first panic after each kind of marker, the trace ids
# 1, 2 and 3 lines above it.
eval "$(awk '
  function tr(s) { return match(s, /trace=[0-9a-f]+/) ? substr(s, RSTART + 6, RLENGTH - 6) : "" }
  / \[deploy\] deploy finished: / { real++ }
  / \[deploy\] deploy finished/ { all++ }
  / panic: / {
    if (!p0) { p0 = 1; print "T_FIRST=" t2 }
    if (real == 1 && !p1) { p1 = 1; print "T_AFTER1=" t2 }
    if (all >= 2 && real < 2 && !pd) { pd = 1; print "T_DRY=" t2 }
    if (real == 2 && !pa) { pa = 1; print "T_ANS=" t2; print "T_UP1=" t1; print "T_UP3=" t3 }
    if (real == 3 && !pz) { pz = 1; print "T_AFTER3=" t2 }
  }
  { t3 = t2; t2 = t1; t1 = tr($0) }
' huge.log)"

GOT="$(tr -d '\r' < trace.txt | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/^trace=//' | grep -v '^$')"
if [ -z "$GOT" ]; then
  echo "❌ trace.txt is empty"
  exit 1
fi
if [ "$(printf '%s\n' "$GOT" | wc -l | tr -d ' ')" -ne 1 ]; then
  echo "❌ trace.txt should hold one trace id only, not several lines"
  exit 1
fi
if [ "$GOT" = "$T_ANS" ]; then
  echo "✅ trace.txt has $T_ANS, the job behind the first panic after the second real deploy"
  exit 0
fi
if ! printf '%s\n' "$GOT" | grep -Eq '^[0-9a-f]{16}$'; then
  echo "❌ trace.txt should contain only the id: the 16 hex digits after trace="
elif [ "$GOT" = "$T_DRY" ]; then
  echo "❌ that panic follows the dry-run marker; a dry run is not a deploy, count only 'deploy finished:' lines"
elif [ "$GOT" = "$T_AFTER1" ]; then
  echo "❌ that panic comes after the FIRST real deploy; the second one is further down"
elif [ "$GOT" = "$T_FIRST" ]; then
  echo "❌ that is the first panic of the day, before any deploy"
elif [ "$GOT" = "$T_AFTER3" ]; then
  echo "❌ that panic is after the third deploy; you went one marker too far"
elif [ -n "$T_UP1" ] && [ "$GOT" = "$T_UP1" ]; then
  echo "❌ that id is on the line directly above the panic; the job's line is two lines above"
elif [ "$GOT" = "$T_UP3" ]; then
  echo "❌ that id is three lines above the panic; count again"
elif grep -q "trace=$GOT" huge.log; then
  echo "❌ that trace id is in huge.log, but not on the line two above the first panic after the second real deploy"
else
  echo "❌ trace.txt does not hold a trace id that appears in huge.log"
fi
exit 1
