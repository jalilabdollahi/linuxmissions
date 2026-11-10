#!/bin/bash
SANDBOX="$1"
OUT="$SANDBOX/status.txt"
LOG="$SANDBOX/.api/access.log"

if [ ! -f "$OUT" ]; then
  echo "❌ status.txt does not exist yet"
  exit 1
fi

if ! grep -q '^GET /health 200 auth=ok$' "$LOG" 2>/dev/null; then
  if grep -q '^GET /health 401' "$LOG" 2>/dev/null; then
    echo "❌ the API answered 401 Unauthorized to every /health request so far; it wants the key in a header"
  else
    echo "❌ the API has not received an authorised request for /health yet"
  fi
  exit 1
fi

got="$(tr -d '\r' < "$OUT" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | sed '/^$/d')"
want="$(cat "$SANDBOX/.api/status")"

if [ "$got" = "$want" ]; then
  echo "✅ status.txt holds service.status from the authorised API call"
  exit 0
fi
if [ "$got" = "\"$want\"" ]; then
  echo "❌ status.txt still has the JSON quotes around the value; save the bare text"
elif [ "$(printf '%s\n' "$got" | wc -l | tr -d ' ')" -gt 1 ]; then
  echo "❌ status.txt has several lines; the response has more than one \"status\" field, you want the one inside \"service\""
else
  echo "❌ status.txt does not contain the value of service.status"
fi
exit 1
