#!/bin/bash
SB="$1"; cd "$SB" || exit 1
alive() { [ -r "/proc/$1/status" ] && ! grep -q '^State:.*Z' "/proc/$1/status"; }
read -r cpid cexe cid < .lm/culprit
if alive "$cpid" && [ "$(readlink "/proc/$cpid/exe" 2>/dev/null)" = "$cexe" ]; then
  echo "❌ the runaway writer is still running (spool/ is still growing)"; exit 1
fi
gone=0
while read -r p id; do
  if ! alive "$p" || ! tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | grep -q "worker.sh $id "; then gone=$((gone+1)); fi
done < .lm/legit.pids
if [ "$gone" -gt 0 ]; then echo "❌ $gone legitimate worker(s) are no longer running: only the one runaway should have been stopped"; exit 1; fi
if ls -A spool | grep -q '^\.dump-'; then echo "❌ the runaway's junk files are still in spool/"; exit 1; fi
miss=0
while read -r p id; do [ -s "spool/w$id.log" ] || miss=$((miss+1)); done < .lm/legit.pids
if [ "$miss" -gt 0 ]; then echo "❌ $miss legitimate spool/w*.log file(s) were deleted or emptied"; exit 1; fi
if [ ! -s culprit.txt ]; then echo "❌ culprit.txt is missing or empty"; exit 1; fi
read -r gp gexe extra < culprit.txt
if [ -n "$extra" ] || [ "$(wc -l < culprit.txt)" -ne 1 ]; then echo "❌ culprit.txt must be a single line: PID, a space, the exe path"; exit 1; fi
if [ "$gp" != "$cpid" ]; then echo "❌ culprit.txt names PID $gp, which is not the process that was flooding spool/"; exit 1; fi
if [ "$(readlink -f "$gexe" 2>/dev/null)" != "$cexe" ]; then echo "❌ culprit.txt has the right PID but the exe path is not that process's real executable"; exit 1; fi
echo "✅ runaway writer stopped, eleven workers intact, junk removed, culprit recorded"
