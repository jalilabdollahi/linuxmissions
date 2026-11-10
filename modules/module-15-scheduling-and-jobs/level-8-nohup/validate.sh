#!/bin/bash
# One migrate.sh must be running with SIGHUP ignored (SigIgn bit 1), stdout
# and stderr on logs/migrate.log, a growing log, no nohup.out, and it must
# survive a real SIGHUP sent by this check.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

find_migrations() {
  pids=()
  for p in $(pgrep -f -- "$SANDBOX/migrate\.sh"); do
    st="$(awk '/^State:/ {print $2}' "/proc/$p/status" 2>/dev/null)"
    [ -n "$st" ] && [ "$st" != Z ] && pids+=("$p")
  done
}
find_migrations
# A copy started a moment ago may not have re-executed itself by its full path yet.
if [ ${#pids[@]} -eq 0 ] && pgrep -f 'migrate\.sh' >/dev/null; then
  sleep 0.5
  find_migrations
fi
if [ ${#pids[@]} -eq 0 ]; then
  echo "❌ migrate.sh is not running"
  exit 1
fi
if [ ${#pids[@]} -gt 1 ]; then
  echo "❌ ${#pids[@]} copies of migrate.sh are running (PIDs ${pids[*]}); two migrations would copy every batch twice, keep one"
  exit 1
fi
pid="${pids[0]}"

log="$(cd logs 2>/dev/null && pwd -P)/migrate.log"
out="$(readlink "/proc/$pid/fd/1")"
err="$(readlink "/proc/$pid/fd/2")"
case "$out" in
  "$log") ;;
  */nohup.out) echo "❌ migrate.sh (PID $pid) writes to nohup.out; its output belongs in logs/migrate.log"; exit 1 ;;
  /dev/pts/*|/dev/tty*) echo "❌ migrate.sh (PID $pid) writes to the terminal, which goes away when you disconnect; send its output to logs/migrate.log"; exit 1 ;;
  *) echo "❌ migrate.sh (PID $pid) writes its output to $out, not logs/migrate.log"; exit 1 ;;
esac
case "$err" in
  "$log") ;;
  /dev/pts/*|/dev/tty*) echo "❌ migrate.sh's error messages (stderr) still go to the terminal; send them to logs/migrate.log too"; exit 1 ;;
  *) echo "❌ migrate.sh's error messages (stderr) go to $err, not logs/migrate.log"; exit 1 ;;
esac
if [ -n "$(find . -name nohup.out -print -quit)" ]; then
  echo "❌ there is a nohup.out from an earlier attempt ($(find . -name nohup.out -print -quit)); remove it, the log is logs/migrate.log"
  exit 1
fi

sigign="$(awk '/^SigIgn:/ {print $2}' "/proc/$pid/status")"
if [ $((16#$sigign & 1)) -eq 0 ]; then
  echo "❌ migrate.sh (PID $pid) does not ignore SIGHUP (SigIgn: $sigign), so a hangup would kill it; start it again so it is immune"
  exit 1
fi

size1=$(wc -c < logs/migrate.log)
sleep 1.6
size2=$(wc -c < logs/migrate.log)
if [ "$size2" -le "$size1" ]; then
  echo "❌ logs/migrate.log is not growing; is migrate.sh stopped (kill -STOP)?"
  exit 1
fi

kill -HUP "$pid" 2>/dev/null
sleep 0.4
if ! kill -0 "$pid" 2>/dev/null; then
  echo "❌ migrate.sh (PID $pid) died when it got SIGHUP"
  exit 1
fi
echo "✅ migrate.sh (PID $pid) survived a hangup and logs to logs/migrate.log"
exit 0
