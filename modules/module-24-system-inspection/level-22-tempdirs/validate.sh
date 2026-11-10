#!/bin/bash
# recovered/app-debug.log has the lost log's sha256, the logger is stopped, stale files
# are gone, recent files and the in-use lock/socket remain, the agent still runs.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/sha ] && [ -s .lm-state/holder.pid ] || { echo "❌ the level's data is gone; type 'reset'"; exit 1; }
alive() { local st; st=$(sed 's/^.*) //' "/proc/$1/stat" 2>/dev/null | cut -c1); [ -n "$st" ] && [ "$st" != Z ] && [ "$st" != X ]; }
[ -f recovered/app-debug.log ] || { echo "❌ recovered/app-debug.log does not exist yet"; exit 1; }
if [ "$(sha256sum < recovered/app-debug.log | cut -d' ' -f1)" != "$(cat .lm-state/sha)" ]; then
  echo "❌ recovered/app-debug.log is not the lost log (wrong or incomplete data; if the holder is already gone the log is lost: type 'reset')"; exit 1
fi
agent=$(cat .lm-state/agent.pid)
if ! alive "$agent"; then echo "❌ the agent that uses tmp/agent.lock and tmp/agent.sock was stopped: you killed too much, type 'reset'"; exit 1; fi
while IFS= read -r p; do
  [ -e "$p" ] || { echo "❌ '$p' was deleted, but it is recent or in use (policy: only old files nobody uses)"; exit 1; }
done < .lm-state/keep
n=0
while IFS= read -r p; do
  [ -e "$p" ] && n=$((n + 1))
done < .lm-state/stale
[ "$n" -eq 0 ] || { echo "❌ $n stale file(s) older than 7 days are still in tmp/"; exit 1; }
if alive "$(cat .lm-state/holder.pid)"; then
  echo "❌ the process that holds the deleted log open is still running (its space is not freed)"; exit 1
fi
echo "✅ log recovered, tmp/ cleaned by policy, the holder is stopped"
exit 0
