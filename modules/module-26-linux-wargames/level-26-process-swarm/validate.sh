#!/bin/bash
SB="$1"; cd "$SB" || exit 1
alive() { [ -r "/proc/$1/status" ] && ! grep -q '^State:.*Z' "/proc/$1/status"; }
swarm_left() {
  local p n=0
  for p in $(pgrep -f "$SB/opt/swarm/" 2>/dev/null); do alive "$p" && n=$((n+1)); done
  echo "$n"
}
apps_ok() {
  local bad=0 p i
  while read -r p i; do
    alive "$p" && tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | grep -q "app.sh $i " || bad=$((bad+1))
  done < .lm/app.pids
  echo "$bad"
}
bad=$(apps_ok)
if [ "$bad" -gt 0 ]; then echo "❌ $bad of the 3 legitimate app processes are gone or were restarted: only the swarm should have been stopped"; exit 1; fi
n=$(swarm_left)
if [ "$n" -gt 0 ]; then echo "❌ $n swarm process(es) are still running"; exit 1; fi
if [ ! -s hidden.txt ]; then echo "❌ hidden.txt is missing or empty"; exit 1; fi
want=$(cat .lm/hidden)
got=$(head -1 hidden.txt | tr -d '\r' | sed 's/[[:space:]]*$//')
if [ "$got" != "$want" ] && [ "$(readlink -f "$got" 2>/dev/null)" != "$want" ]; then
  echo "❌ hidden.txt does not name the real executable of the disguised member (a kernel thread has no executable at all)"; exit 1; fi
for i in $(seq 1 20); do
  sleep 0.5
  n=$(swarm_left)
  if [ "$n" -gt 0 ]; then echo "❌ the swarm came back: $n process(es) running again within 10 seconds"; exit 1; fi
done
bad=$(apps_ok)
if [ "$bad" -gt 0 ]; then echo "❌ an app process died while the swarm was being removed"; exit 1; fi
echo "✅ swarm gone and staying gone, app processes untouched, disguised member identified"
