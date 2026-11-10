#!/bin/bash
# The truth is read from the running worker's /proc/<pid>/environ, so nothing
# about the expected values is stored in the sandbox.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -d /proc/self ]; then
  echo "❌ this level needs Linux (/proc); play it with ./play.sh --docker"
  exit 1
fi
pid="$(pgrep -f "bash $SANDBOX/bin/worker\$" | head -1)"
if [ -z "$pid" ] || [ ! -r "/proc/$pid/environ" ]; then
  echo "❌ the worker process is not running any more; type reset to start it again"
  exit 1
fi
live="$(tr '\0' '\n' < "/proc/$pid/environ" | grep -E '^(DB_HOST|QUEUE|POOL)=' | LC_ALL=C sort)"

if [ ! -f live.env ]; then
  echo "❌ live.env does not exist yet"
  exit 1
fi
got="$(tr -d '\r' < live.env | grep -v '^[[:space:]]*$' | sed 's/^export //' | LC_ALL=C sort)"
for key in DB_HOST QUEUE POOL; do
  line="$(printf '%s\n' "$got" | grep "^$key=")"
  n="$(printf '%s\n' "$got" | grep -c "^$key=")"
  if [ "$n" -eq 0 ]; then
    echo "❌ live.env has no $key= line"
    exit 1
  fi
  if [ "$n" -gt 1 ]; then
    echo "❌ live.env has $key more than once"
    exit 1
  fi
  want="$(printf '%s\n' "$live" | grep "^$key=")"
  if [ "$line" != "$want" ]; then
    if grep -qx "$line" worker.env; then
      echo "❌ live.env's $key is the value from worker.env, not the one the running worker has"
    else
      echo "❌ live.env's $key is not the value the running worker has"
    fi
    exit 1
  fi
done
if [ "$(printf '%s\n' "$got" | grep -c .)" -ne 3 ]; then
  echo "❌ live.env should contain exactly the three lines DB_HOST, QUEUE and POOL"
  exit 1
fi

if [ ! -f stale.txt ]; then
  echo "❌ stale.txt does not exist yet"
  exit 1
fi
want_stale="$(for key in DB_HOST QUEUE POOL; do
  [ "$(printf '%s\n' "$live" | grep "^$key=")" != "$(grep "^$key=" worker.env)" ] && echo "$key"
done | LC_ALL=C sort)"
got_stale="$(tr -d '\r' < stale.txt | sed 's/[[:space:]]//g; s/=.*//' | grep -v '^$' | LC_ALL=C sort -u)"
if [ "$got_stale" != "$want_stale" ]; then
  wn="$(printf '%s\n' "$want_stale" | grep -c .)"
  echo "❌ stale.txt does not list the right keys ($wn of the three differ between the worker and worker.env)"
  exit 1
fi

echo "✅ live.env matches what worker (pid $pid) really runs with; stale: $(printf '%s' "$want_stale" | paste -sd, -)"
exit 0
