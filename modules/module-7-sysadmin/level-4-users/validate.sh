#!/bin/bash
SANDBOX="$1"

if grep -q '^devuser:' "$SANDBOX/passwd.mock" && grep -Eq '^docker:.*(^|,)devuser(,|$)' "$SANDBOX/group.mock"; then
  echo "✅ PASS: devuser was created and added to the docker group"
  exit 0
fi

echo "❌ FAIL: devuser must exist and be a member of docker"
exit 1
