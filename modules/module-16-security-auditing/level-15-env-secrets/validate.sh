#!/bin/bash
# The leaking worker must have been restarted with its password coming from secrets/db.pass
# (600), with neither its command line nor its environment containing the password, the
# quiet worker must be untouched, start-worker.sh must not hold the password any more and
# leak.txt must name the original PID of the leaking worker.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/leaker.pid ] || { echo "❌ internal state missing, type 'reset'"; exit 1; }
leaker=$(cat .lm-state/leaker.name); quiet=$(cat .lm-state/quiet.name)
oldpid=$(cat .lm-state/leaker.pid); quietpid=$(cat .lm-state/quiet.pid); pw=$(cat .lm-state/leaker.pw)

if ps -eo args= | grep -F -- "$pw" | grep -vF "grep" | grep -q .; then
  echo "❌ a running process still shows the database password in its command line"; exit 1
fi
kill -0 "$quietpid" 2>/dev/null || { echo "❌ the $quiet worker is no longer running: it was not leaking, so it should not have been touched"; exit 1; }
if kill -0 "$oldpid" 2>/dev/null; then
  echo "❌ the original $leaker worker (the one that leaked) is still running"; exit 1
fi
newpids=$(ps -eo pid=,args= | awk -v w="$SANDBOX/app/worker.sh $leaker" '$2 == "bash" && index($0, w) { print $1 }')
n=$(echo "$newpids" | grep -c .)
[ "$n" -ge 1 ] || { echo "❌ no $leaker worker is running: start it again after fixing start-worker.sh"; exit 1; }
[ "$n" -eq 1 ] || { echo "❌ $n copies of the $leaker worker are running, there should be one"; exit 1; }
newpid=$newpids
tr '\0' '\n' < "/proc/$newpid/environ" 2>/dev/null | grep -qF -- "$pw" && { echo "❌ the new $leaker worker has the password in its environment"; exit 1; }
[ -f app/start-worker.sh ] || { echo "❌ app/start-worker.sh is missing"; exit 1; }
grep -qF -- "$pw" app/start-worker.sh && { echo "❌ app/start-worker.sh still contains the password"; exit 1; }
[ -f secrets/db.pass ] || { echo "❌ secrets/db.pass does not exist"; exit 1; }
[ "$(stat -c %a secrets/db.pass)" = 600 ] || { echo "❌ secrets/db.pass has mode $(stat -c %a secrets/db.pass), expected 600"; exit 1; }
[ "$(cat secrets/db.pass)" = "$pw" ] || { echo "❌ secrets/db.pass does not hold the $leaker database password"; exit 1; }
for _ in $(seq 20); do grep -q "\[pid $newpid\] $leaker: connected" "logs/$leaker.log" && break; sleep 0.1; done
grep -q "\[pid $newpid\] $leaker: connected" "logs/$leaker.log" || { echo "❌ the new $leaker worker did not report 'connected' in logs/$leaker.log"; exit 1; }
[ -s leak.txt ] || { echo "❌ leak.txt is missing or empty"; exit 1; }
grep -qw -- "$oldpid" leak.txt || { echo "❌ leak.txt does not name the PID of the worker that leaked"; exit 1; }
grep -qw -- "$quietpid" leak.txt && { echo "❌ leak.txt also names a worker that did not leak"; exit 1; }
echo "✅ the $leaker worker now reads its password from a 600 file and the leak is documented"
exit 0
