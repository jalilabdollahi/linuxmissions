#!/bin/bash
# needs-restart.txt must hold exactly the units whose process mapped the
# deleted libssl; those were restarted, the others were not, and no sandbox
# process maps a deleted copy any more.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
SC=bin/systemctl
LIBRE='libssl\.so\.3 \(deleted\)'

if [ ! -s .lm-state/pids ]; then
  echo "❌ the level's data is gone; type 'reset'"
  exit 1
fi
if [ ! -s needs-restart.txt ]; then
  echo "❌ needs-restart.txt is missing or empty"
  exit 1
fi

# every sandbox process that still maps a deleted libssl
stale=$(for d in /proc/[0-9]*; do
  grep -qaF "$SANDBOX" "$d/cmdline" 2>/dev/null || continue
  grep -q "$LIBRE" "$d/maps" 2>/dev/null && echo "${d#/proc/}"
done)
if [ -n "$stale" ]; then
  echo "❌ $(echo "$stale" | wc -l | tr -d ' ') process(es) still map the old, deleted libssl (PIDs: $(echo $stale | tr ' ' ',')); restart their services"
  exit 1
fi

want=$(awk '$2 == "map-old" { print $1 }' .lm-state/pids | sort)
got=$(tr -d '\r' < needs-restart.txt | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' | sort -u)
if [ "$got" != "$want" ]; then
  extra=$(comm -13 <(echo "$want") <(echo "$got") | head -1)
  missing=$(comm -23 <(echo "$want") <(echo "$got") | head -1)
  if [ -n "$extra" ]; then
    echo "❌ needs-restart.txt lists $extra, which was not using the deleted library"
  else
    echo "❌ needs-restart.txt does not list every affected service ($(echo "$want" | wc -l | tr -d ' ') expected, $(echo "$got" | wc -l | tr -d ' ') listed); one is missing"
  fi
  exit 1
fi

while read -r unit role pid; do
  now=$($SC show -P MainPID "$unit")
  if [ "$($SC is-active "$unit" 2>/dev/null)" != active ] || [ "$now" = 0 ]; then
    echo "❌ $unit is not running"
    exit 1
  fi
  if [ "$role" = map-old ] && [ "$now" = "$pid" ]; then
    echo "❌ $unit is still the old process (PID $pid); the list is right but it was not restarted"
    exit 1
  fi
  if [ "$role" != map-old ] && [ "$now" != "$pid" ]; then
    echo "❌ $unit was restarted although it never used the deleted library; only restart what needs it"
    exit 1
  fi
done < .lm-state/pids

echo "✅ $(echo "$want" | wc -l | tr -d ' ') services restarted ($(echo $want | tr ' ' ',')); nothing maps the deleted libssl any more"
exit 0
