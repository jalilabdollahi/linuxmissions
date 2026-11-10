#!/bin/bash
SANDBOX="$1"
CULPRIT=$(cat "$SANDBOX/.culprit.pid" 2>/dev/null)

if [ -z "$CULPRIT" ] || ! ps -o stat= -p "$CULPRIT" 2>/dev/null | grep -qv '^Z'; then
  echo "❌ The runaway job is not running any more: type reset to start the level again"
  exit 1
fi

if [ ! -f "$SANDBOX/top_procs.txt" ]; then
  echo "❌ top_procs.txt not found"
  exit 1
fi
# Process lines = lines with at least 3 columns and a number in them; the header is skipped
procs=$(grep -v '%CPU' "$SANDBOX/top_procs.txt" | awk 'NF >= 3 && /[0-9]/')
nprocs=$(printf '%s\n' "$procs" | grep -c .)
if [ "$nprocs" -lt 5 ]; then
  echo "❌ top_procs.txt has $nprocs process line(s), expected the top 5 from ps"
  exit 1
fi
# Which column is %CPU? Take it from ps's header if there is one, else assume ps aux (3rd).
col=$(awk '/%CPU/ { for (i = 1; i <= NF; i++) if ($i == "%CPU") { print i; exit } }' "$SANDBOX/top_procs.txt")
col=${col:-3}
if ! printf '%s\n' "$procs" | head -5 | awk -v c="$col" '
       { v = $c + 0; if (NR > 1 && v > prev) bad = 1; prev = v } END { exit bad }'; then
  echo "❌ top_procs.txt is not sorted by CPU usage, highest first"
  exit 1
fi
if ! printf '%s\n' "$procs" | head -5 | grep -qw "$CULPRIT"; then
  echo "❌ top_procs.txt doesn't show the biggest CPU users first (sort by %CPU, highest first)"
  exit 1
fi
if ! grep -qw "$CULPRIT" <(printf '%s\n' "$procs" | grep 'report_builder'); then
  echo "❌ top_procs.txt needs the command column too, so you can see what each process is"
  exit 1
fi

if [ ! -f "$SANDBOX/culprit.txt" ]; then
  echo "❌ top_procs.txt looks good; now save the runaway job's PID to culprit.txt"
  exit 1
fi
if [ "$(tr -d '[:space:]' < "$SANDBOX/culprit.txt")" != "$CULPRIT" ]; then
  echo "❌ culprit.txt does not contain the PID of the runaway sandbox job"
  exit 1
fi
echo "✅ Found it: PID $CULPRIT (report_builder.sh) is the CPU hog"
exit 0
