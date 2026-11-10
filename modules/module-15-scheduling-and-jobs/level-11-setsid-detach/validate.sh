#!/bin/bash
# Exactly one consumer.sh: SID == PID (session leader), no controlling
# terminal, fd 0 = /dev/null, fd 1 and 2 = logs/consumer.log opened for
# append, and it still moves a fresh message from queue/ to done/.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

pids=()
for p in $(pgrep -f -- "$SANDBOX/consumer\.sh"); do
  st="$(awk '/^State:/ {print $2}' "/proc/$p/status" 2>/dev/null)"
  [ -n "$st" ] && [ "$st" != Z ] && pids+=("$p")
done
if [ ${#pids[@]} -eq 0 ] && pgrep -f 'consumer\.sh' >/dev/null; then
  sleep 0.5   # just started: it re-executes itself by its full path first
  for p in $(pgrep -f -- "$SANDBOX/consumer\.sh"); do pids+=("$p"); done
fi
if [ ${#pids[@]} -eq 0 ]; then
  echo "❌ consumer.sh is not running"
  exit 1
fi
if [ ${#pids[@]} -gt 1 ]; then
  echo "❌ ${#pids[@]} consumers are running (PIDs ${pids[*]}); two consumers would race for the same messages, keep one"
  exit 1
fi
pid="${pids[0]}"
read -r sid tty <<< "$(ps -o sid=,tty= -p "$pid")"
if [ "$tty" != "?" ]; then
  echo "❌ consumer.sh (PID $pid) still has the controlling terminal $tty, so a hangup or Ctrl-C there can reach it"
  exit 1
fi
if [ "$sid" != "$pid" ]; then
  echo "❌ consumer.sh (PID $pid) is in session $sid, not a session of its own (its SID should be its PID)"
  exit 1
fi
in="$(readlink "/proc/$pid/fd/0")"
if [ "$in" != /dev/null ]; then
  echo "❌ consumer.sh reads stdin from ${in:-nothing}; give it /dev/null"
  exit 1
fi
log="$(cd logs && pwd -P)/consumer.log"
for fd in 1 2; do
  target="$(readlink "/proc/$pid/fd/$fd")"
  name=$([ $fd = 1 ] && echo stdout || echo stderr)
  if [ "$target" != "$log" ]; then
    echo "❌ consumer.sh's $name goes to ${target:-nowhere}, not logs/consumer.log"
    exit 1
  fi
  flags="$(awk '/^flags:/ {print $2}' "/proc/$pid/fdinfo/$fd")"
  if [ $((8#$flags & 02000)) -eq 0 ]; then
    echo "❌ consumer.sh's $name overwrites logs/consumer.log; append to it, the old lines must stay"
    exit 1
  fi
done
if ! grep -q 'consumer gone after the SSH session' logs/consumer.log; then
  echo "❌ the earlier lines of logs/consumer.log are gone; append (>>) instead of overwriting (type reset)"
  exit 1
fi

probe="check-$$-$RANDOM.msg"
printf 'order=probe\n' > "queue/$probe"
for _ in 1 2 3 4 5 6 7 8; do
  [ -e "done/$probe" ] && break
  sleep 0.5
done
if [ ! -e "done/$probe" ]; then
  rm -f "queue/$probe"
  echo "❌ consumer.sh (PID $pid) did not process a new message within 4 seconds; is it stopped?"
  exit 1
fi
rm -f "done/$probe"
echo "✅ consumer.sh (PID $pid) runs in its own session with no terminal and keeps processing the queue"
exit 0
