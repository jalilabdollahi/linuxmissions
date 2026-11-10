#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/jobs.txt" ]; then
  if [ -f "$SANDBOX/result.txt" ]; then
    echo "❌ process.sh finished, but jobs.txt is missing: start it again in the background and save the job list while it runs"
  else
    echo "❌ jobs.txt not found"
  fi
  exit 1
fi
if ! grep -q 'process\.sh' "$SANDBOX/jobs.txt" || ! grep -qi 'running' "$SANDBOX/jobs.txt"; then
  echo "❌ jobs.txt doesn't show process.sh as a Running job (save the list while the job is still running)"
  exit 1
fi
if ! grep -Eq '^\[[0-9]+\][+-]? +[0-9]+ ' "$SANDBOX/jobs.txt"; then
  echo "❌ jobs.txt has no PIDs: ask the job list to include them"
  exit 1
fi
if [ ! -f "$SANDBOX/result.txt" ]; then
  echo "❌ result.txt not there yet: wait for the job to finish"
  exit 1
fi
PID=$(sed -n 's/^done: 10\/10 batches processed by PID \([0-9][0-9]*\)$/\1/p' "$SANDBOX/result.txt")
if [ -z "$PID" ]; then
  echo "❌ result.txt was not written by process.sh"
  exit 1
fi
if ! grep -Eq "^\[[0-9]+\][+-]? +$PID +Running .*process\.sh" "$SANDBOX/jobs.txt"; then
  echo "❌ The run that wrote result.txt (PID $PID) is not the one in jobs.txt; save the job list during the same run"
  exit 1
fi
echo "✅ process.sh ran as background job PID $PID and finished"
exit 0
