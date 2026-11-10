# Runs the player's healthcheck.sh twice: with the worker up (must exit 0, say OK)
# and after stopping the worker (must exit 1, say DOWN) while the .bak decoy is
# still running. The worker is started again afterwards.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/worker.pid ] || [ ! -f opt/queue-worker.sh ]; then echo "❌ the level's data is gone; type 'reset'"; exit 1; fi
start_worker() {
  "$SANDBOX/opt/queue-worker.sh" >/dev/null 2>&1 &
  echo $! > .lm-state/worker.pid
  sleep 0.3
}
alive() { kill -0 "$1" 2>/dev/null && [ "$(ps -o stat= -p "$1" | cut -c1)" != Z ]; }
alive "$(cat .lm-state/worker.pid)" || start_worker
if ! alive "$(cat .lm-state/bak.pid)"; then
  "$SANDBOX/opt/queue-worker.bak" >/dev/null 2>&1 &
  echo $! > .lm-state/bak.pid
fi
if [ ! -f healthcheck.sh ]; then echo "❌ healthcheck.sh is gone; it has to stay where it is"; exit 1; fi

out=$(timeout 10 bash healthcheck.sh 2>&1); rc=$?
if [ $rc -ne 0 ]; then
  echo "❌ with the worker running, healthcheck.sh exits $rc (it prints: ${out:-nothing}); it must exit 0"
  exit 1
fi
if ! echo "$out" | grep -q OK; then
  echo "❌ healthcheck.sh exits 0 but does not print an OK line (it prints: ${out:-nothing})"
  exit 1
fi

pid=$(cat .lm-state/worker.pid)
kill "$pid" 2>/dev/null
for _ in $(seq 1 30); do alive "$pid" || break; sleep 0.1; done
if alive "$pid"; then kill -9 "$pid" 2>/dev/null; sleep 0.2; fi
out=$(timeout 10 bash healthcheck.sh 2>&1); rc=$?
start_worker
if [ $rc -ne 1 ]; then
  echo "❌ with the worker stopped, healthcheck.sh exits $rc instead of 1: it reports the worker up when it is not (does the pattern also match the backup copy, or the check's own command line?)"
  exit 1
fi
if ! echo "$out" | grep -q DOWN; then
  echo "❌ with the worker stopped, healthcheck.sh exits 1 but does not print a DOWN line (it prints: ${out:-nothing})"
  exit 1
fi
echo "✅ healthcheck.sh sees the worker when it runs, reports DOWN when it stops, and ignores queue-worker.bak"
exit 0
