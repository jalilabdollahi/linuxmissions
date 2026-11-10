#!/bin/bash
# Supervisor + 12 workers (worker.sh report-N). Stuck: report-1 and two more from
# the others (never 10-12 all at once, so `pkill -f report-1` hurts 10, 11 and
# the supervisor too). Stuck workers stop touching their heartbeat (their
# mtime is set 6-40 minutes back); healthy ones touch every 5 s. All trap TERM
# and log a clean-shutdown line, SIGKILL leaves no line.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p opt run/hb log .lm-state

cat > opt/worker.sh <<'LMEND'
#!/bin/bash
# report worker; usage: worker.sh NAME. Touches its heartbeat every 5 s unless hung.
root=$(cd "$(dirname "$0")/.." && pwd)
name=$1
hung=0
grep -qx "$name" "$root/.lm-state/hung" && hung=1
sleeper=""
trap 'echo "$(date +%T) $name: SIGTERM received, state flushed, clean shutdown" >> "$root/log/workers.log"; [ -n "$sleeper" ] && kill "$sleeper" 2>/dev/null; exit 0' TERM
while :; do
  [ "$hung" = 0 ] && touch "$root/run/hb/$name"
  sleep 5 & sleeper=$!
  wait "$sleeper"
done
LMEND
cat > opt/report-supervisor.sh <<'LMEND'
#!/bin/bash
# starts report-1 .. report-12 and keeps watch (does not restart them)
root=$(cd "$(dirname "$0")/.." && pwd)
for i in $(seq 1 12); do
  bash "$root/opt/worker.sh" "report-$i" &
done
while :; do sleep 20; done
LMEND

others=(2 3 4 5 6 7 8 9 12)
mapfile -t pick < <(printf '%s\n' "${others[@]}" | shuf | head -2)
printf 'report-1\nreport-%s\nreport-%s\n' "${pick[0]}" "${pick[1]}" > .lm-state/hung
for i in $(seq 1 12); do touch "run/hb/report-$i"; done
: > log/workers.log

bash "$SANDBOX/opt/report-supervisor.sh" >/dev/null 2>&1 &
sleep 1.5
for n in $(cat .lm-state/hung); do
  touch -d "$((6 + RANDOM % 35)) minutes ago" "run/hb/$n"
done

sup=$(pgrep -f "$SANDBOX/opt/report-supervisor.sh\$" | head -1)
[ -n "$sup" ] || { echo "supervisor did not start" >&2; exit 1; }
echo "supervisor $sup" > .lm-state/pids
for i in $(seq 1 12); do
  pid=$(pgrep -f "$SANDBOX/opt/worker.sh report-$i\$" | head -1)
  [ -n "$pid" ] || { echo "worker report-$i did not start" >&2; exit 1; }
  echo "report-$i $pid" >> .lm-state/pids
done
