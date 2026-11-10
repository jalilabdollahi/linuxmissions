#!/bin/bash
SANDBOX="$1"
FILE="$SANDBOX/errors.txt"

if [ ! -f "$FILE" ]; then
  echo "❌ errors.txt not found"
  exit 1
fi

EXPECTED='Failed to bind 0.0.0.0:8080: Address already in use
database connection refused (db01:5432)
Out of memory: worker 3 killed
payment webhook rejected: invalid signature from 203.0.113.9'

# Accept the default (short), short-iso and cat output formats: keep only the message.
ACTUAL="$(tr -d '\r' < "$FILE" | sed '/^[[:space:]]*$/d' | sed -E 's/^.* myapp\[[0-9]+\]: //')"

if [ "$ACTUAL" = "$EXPECTED" ]; then
  echo "✅ errors.txt holds exactly myapp's err-or-worse entries since 14:00"
  exit 0
fi

n_actual="$(printf '%s\n' "$ACTUAL" | sed '/^$/d' | wc -l | tr -d ' ')"
if grep -q 'web01 [a-z-]*\[' "$FILE" && grep -v 'myapp\[' "$FILE" | grep -q 'web01'; then
  echo "❌ errors.txt contains entries from other units; only myapp.service is wanted"
elif printf '%s\n' "$ACTUAL" | grep -Eq 'error_rate|retrying|slow query|memory limit|config reloaded|starting|listening|SIGTERM|restored'; then
  echo "❌ errors.txt contains entries below priority err (info/warning lines that merely mention errors)"
elif printf '%s\n' "$ACTUAL" | grep -Eq 'cache warmup|session file'; then
  echo "❌ errors.txt contains entries from before 14:00 today"
elif [ "$(printf '%s\n' "$ACTUAL" | sort)" = "$(printf '%s\n' "$EXPECTED" | sort)" ]; then
  echo "❌ errors.txt has the right entries but not in journal order (oldest first)"
else
  echo "❌ errors.txt has $n_actual entries, but they are not the err-or-worse myapp entries since 14:00"
fi
exit 1
