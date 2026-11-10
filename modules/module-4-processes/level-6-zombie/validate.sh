#!/bin/bash
SANDBOX="$1"

# Alive = exists and is not a zombie. A killed process can stay in state Z
# until something reaps it (e.g. in containers whose PID 1 never calls wait).
alive() {
  local st
  st=$(ps -o stat= -p "$1" 2>/dev/null) || return 1
  [ -n "$st" ] && [[ "$st" != Z* ]]
}

PARENT=$(cat "$SANDBOX/.parent.pid" 2>/dev/null)
AGENT=$(cat "$SANDBOX/.agent.pid" 2>/dev/null)
if [ -z "$PARENT" ] || [ -z "$AGENT" ] || [ ! -s "$SANDBOX/.zombies.expected" ]; then
  echo "❌ Level state is missing: type reset"
  exit 1
fi

if [ ! -s "$SANDBOX/zombies.txt" ]; then
  echo "❌ zombies.txt not found or empty"
  exit 1
fi
missing=0
while read -r z; do
  [ -z "$z" ] && continue
  awk -v z="$z" '{ for (i = 1; i <= NF; i++) if ($i == z) found = 1 } END { exit !found }' \
    "$SANDBOX/zombies.txt" || missing=$((missing + 1))
done < "$SANDBOX/.zombies.expected"
if [ "$missing" -gt 0 ]; then
  if alive "$PARENT"; then
    echo "❌ zombies.txt is missing $missing of the 3 zombie PIDs"
  else
    echo "❌ zombies.txt is missing $missing of the 3 zombie PIDs, and the parent is already gone so they were reaped (type reset)"
  fi
  exit 1
fi

if ! alive "$AGENT"; then
  echo "❌ metrics_agent.py was stopped too; only the zombies' parent had to go (type reset)"
  exit 1
fi
if alive "$PARENT"; then
  echo "❌ zombies.txt is right; the parent of the zombies is still running"
  exit 1
fi
echo "✅ Zombies documented, their parent (PID $PARENT) stopped, metrics_agent.py untouched"
exit 0
