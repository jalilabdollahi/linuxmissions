#!/bin/bash
# worker_env.txt must be exactly the APP_ENV and DB_HOST of the running worker.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/expected ] || { echo "❌ the level's data is gone; type 'reset'"; exit 1; }
[ -f worker_env.txt ] || { echo "❌ worker_env.txt does not exist yet"; exit 1; }
want=$(cat .lm-state/expected)
pid=$(cat .lm-state/worker.pid 2>/dev/null)
if [ -r "/proc/$pid/environ" ]; then   # prefer the live process
  want=$(tr '\0' '\n' < "/proc/$pid/environ" | grep -E '^(APP_ENV|DB_HOST)=' | sort -t= -k1,1r)
  want=$(printf '%s\n%s\n' "$(printf '%s\n' "$want" | grep '^APP_ENV=')" "$(printf '%s\n' "$want" | grep '^DB_HOST=')")
fi
got=$(tr -d '\r' < worker_env.txt | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$')
[ -n "$got" ] || { echo "❌ worker_env.txt is empty"; exit 1; }
if [ "$got" = "$want" ]; then
  echo "✅ the worker really runs with $(echo "$want" | head -1) and $(echo "$want" | tail -1)"; exit 0
fi
if grep -qx 'APP_ENV=production' <<< "$got" && ! grep -qx 'APP_ENV=production' <<< "$want"; then
  echo "❌ APP_ENV=production is what the config file says (or the metrics exporter has), not what the worker was started with"
elif [ "$(echo "$got" | wc -l | tr -d ' ')" -ne 2 ]; then
  echo "❌ worker_env.txt must have exactly two lines: APP_ENV=... then DB_HOST=..."
elif ! grep -q '^APP_ENV=' <<< "$got" || ! grep -q '^DB_HOST=' <<< "$got"; then
  echo "❌ the lines must start with APP_ENV= and DB_HOST="
else
  echo "❌ the values do not match the environment of the running worker (look out for similarly named variables)"
fi
exit 1
