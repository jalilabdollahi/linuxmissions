#!/bin/bash
# memory.env must hold available (not free!), swap used and the right verdict.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/want ] || [ ! -s free2.txt ]; then echo "❌ the level's data is gone; type 'reset'"; exit 1; fi
. .lm-state/want
getv() { sed -n "s/^$1=//p" memory.env 2>/dev/null | tail -1 | tr -d ' "\r'; }

for k in available_mib swap_used_mib verdict; do
  [ -n "$(getv $k)" ] || { echo "❌ $k is still empty in memory.env"; exit 1; }
done
a=$(getv available_mib)
if [ "$a" = "$FREE2" ]; then
  echo "❌ available_mib is the 'free' column: that is memory nobody has touched, and the kernel keeps it small on purpose; the figure that matters is 'available'"
  exit 1
fi
if [ "$a" != "$AVAIL" ]; then
  echo "❌ available_mib is $a, which is not the available figure in the 10:00 capture (free2.txt)"
  exit 1
fi
if [ "$(getv swap_used_mib)" != "$SWAP" ]; then
  echo "❌ swap_used_mib is $(getv swap_used_mib), which is not the swap used in the 10:00 capture"
  exit 1
fi
v=$(getv verdict)
if [ "$v" != ok ] && [ "$v" != pressure ]; then
  echo "❌ verdict must be 'ok' or 'pressure', not '$v'"
  exit 1
fi
if [ "$v" != "$VERDICT" ]; then
  if [ "$VERDICT" = pressure ]; then
    echo "❌ verdict $v is wrong: apply both parts of the rule in TICKET.md (available vs 10 % of total, and swap used at 10:00 vs 09:50)"
  else
    echo "❌ verdict $v is wrong: by the rule in TICKET.md this box is not under pressure; check both parts of the rule against the numbers"
  fi
  exit 1
fi
echo "✅ memory.env is right: $AVAIL MiB available, $SWAP MiB swap in use, verdict $VERDICT"
exit 0
