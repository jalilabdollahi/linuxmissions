#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/at.queue" ]; then
  echo "❌ FAIL: no at queue entry found"
  exit 1
fi

if grep -Fq './cleanup.sh' "$SANDBOX/at.queue" && grep -Fq 'now + 1 minute' "$SANDBOX/at.queue"; then
  echo "✅ PASS: cleanup.sh was scheduled as a one-time job"
  exit 0
fi

echo "❌ FAIL: the queued job should schedule ./cleanup.sh for now + 1 minute"
exit 1
