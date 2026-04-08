#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/run_all.sh" ]; then
  echo "❌ FAIL: run_all.sh not found"
  exit 1
fi

CONTENT="$(cat "$SANDBOX/run_all.sh")"
if ! printf '%s' "$CONTENT" | grep -q 'wait'; then
  echo "❌ FAIL: run_all.sh should wait for all background jobs"
  exit 1
fi

rm -f "$SANDBOX"/a.out "$SANDBOX"/b.out "$SANDBOX"/c.out
(cd "$SANDBOX" && bash ./run_all.sh >/dev/null 2>&1)

if [ -f "$SANDBOX/a.out" ] && [ -f "$SANDBOX/b.out" ] && [ -f "$SANDBOX/c.out" ]; then
  echo "✅ PASS: run_all.sh completed all three tasks"
  exit 0
fi

echo "❌ FAIL: Not all task outputs were created"
exit 1
