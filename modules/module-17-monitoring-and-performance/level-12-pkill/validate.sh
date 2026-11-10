SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/pids ] || [ ! -s .lm-state/hung ]; then echo "❌ the level's data is gone; type 'reset'"; exit 1; fi
alive() { [ -r /proc/$1/status ] && [ "$(ps -o stat= -p "$1" 2>/dev/null | cut -c1)" != Z ]; }
sleep 0.5
while read -r name pid; do
  if grep -qx "$name" .lm-state/hung; then continue; fi
  if ! alive "$pid"; then
    case $name in
      supervisor) echo "❌ the report supervisor (PID $pid) is gone; its command line also contains 'report-', so a loose pattern kills it too";;
      *) echo "❌ $name is healthy (fresh heartbeat) but was terminated; make sure the pattern cannot match longer names such as report-10 when you mean report-1";;
    esac
    exit 1
  fi
done < .lm-state/pids
for name in $(cat .lm-state/hung); do
  pid=$(awk -v n="$name" '$1==n {print $2}' .lm-state/pids)
  for _ in $(seq 1 30); do alive "$pid" || break; sleep 0.1; done
  if alive "$pid"; then
    echo "❌ $name (heartbeat older than 2 minutes) is still running"
    exit 1
  fi
  n=$(grep -c " $name: SIGTERM received" log/workers.log)
  if [ "$n" != 1 ]; then
    echo "❌ $name is gone but never logged its clean shutdown in log/workers.log; it was killed without the chance to flush (SIGKILL?), the default signal does it gracefully"
    exit 1
  fi
done
# also make sure the heartbeat check agrees with the hidden list
for f in run/hb/*; do
  n=$(basename "$f")
  if find "$f" -mmin +2 | grep -q . && ! grep -qx "$n" .lm-state/hung; then
    echo "❌ $n has an old heartbeat but is not one of the workers that were stuck"
    exit 1
  fi
done
echo "✅ the three stuck workers shut down cleanly; the nine healthy workers and the supervisor are still running"
exit 0
