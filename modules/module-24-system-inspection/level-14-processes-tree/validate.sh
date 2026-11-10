#!/bin/bash
# chain.txt must hold the recorded PID chain (worker --job 7 up to supervisor.sh),
# and no process of the job runner may be left (nothing respawns) after a pause.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/expected ] || { echo "❌ the level's data is gone; type 'reset'"; exit 1; }
[ -f chain.txt ] || { echo "❌ chain.txt does not exist yet"; exit 1; }
got=$(tr -d '\r' < chain.txt | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$')
want=$(cat .lm-state/expected)
[ -n "$got" ] || { echo "❌ chain.txt is empty"; exit 1; }
if [ "$got" != "$want" ]; then
  if grep -qE '[^0-9]' <<< "$got"; then
    echo "❌ chain.txt must contain only PIDs, one per line"
  elif [ "$got" = "$(tac <<< "$want")" ]; then
    echo "❌ the chain is right but upside down: the worker first, supervisor.sh last"
  elif [ "$(wc -l <<< "$got")" -lt "$(wc -l <<< "$want")" ]; then
    echo "❌ chain.txt stops too early: keep following the parent PIDs up to supervisor.sh"
  elif ! grep -qx "$(head -1 <<< "$want")" <<< "$got"; then
    echo "❌ the first PID is not the worker running --job 7 (a similar job number is not the same job)"
  else
    echo "❌ chain.txt does not match the parent chain of the stuck worker"
  fi
  exit 1
fi
sleep 2.5   # a respawn takes up to a second: give it time to show up
left=$(pgrep -f "$SANDBOX/opt/jobrunner" | wc -l | tr -d ' ')
if [ "$left" -gt 0 ]; then
  if pgrep -f "$SANDBOX/opt/jobrunner/supervisor\.sh" >/dev/null; then
    echo "❌ the supervisor is still running: it restarts everything below it"
  else
    echo "❌ $left job runner process(es) are still alive (or came back): stop every layer"
  fi
  exit 1
fi
echo "✅ chain recorded and the whole job runner is down"
exit 0
