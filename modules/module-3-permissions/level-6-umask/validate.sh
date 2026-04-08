#!/bin/bash
SANDBOX="$1"
if [ ! -f "$SANDBOX/umask_answer.txt" ]; then
  echo "❌ FAIL: umask_answer.txt not found"; exit 1
fi
if grep -q "027" "$SANDBOX/umask_answer.txt"; then
  echo "✅ PASS: Correct! umask 027 → files 640, dirs 750"
  exit 0
fi
echo "❌ FAIL: The correct umask is 027. Got: $(cat $SANDBOX/umask_answer.txt)"
exit 1
