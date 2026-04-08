#!/bin/bash
SANDBOX="$1"
if [ ! -x "$SANDBOX/deploy.sh" ]; then
  echo "❌ FAIL: deploy.sh is not executable"
  exit 1
fi
if [ ! -f "$SANDBOX/output.txt" ]; then
  echo "❌ FAIL: output.txt not found — did you run deploy.sh?"
  exit 1
fi
if grep -q "Deployment successful" "$SANDBOX/output.txt"; then
  echo "✅ PASS: deploy.sh is executable and was run successfully"
  exit 0
fi
echo "❌ FAIL: output.txt doesn't contain expected content"
exit 1
