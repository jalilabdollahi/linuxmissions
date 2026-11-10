#!/bin/bash
SANDBOX="$1"
SCRIPT="$SANDBOX/deploy.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ deploy.sh is gone (type reset to get it back)"
  exit 1
fi
if [ ! -x "$SCRIPT" ]; then
  echo "❌ deploy.sh is still not executable for its owner"
  exit 1
fi
MODE=$(stat -c '%a' "$SCRIPT" 2>/dev/null || stat -f '%Lp' "$SCRIPT")
if (( 8#$MODE & 8#022 )); then
  echo "❌ deploy.sh is now writable by group or others (mode $MODE): add execute only, don't open it up"
  exit 1
fi
if [ ! -f "$SANDBOX/output.txt" ]; then
  echo "❌ output.txt not found: deploy.sh is executable now, but has it been run?"
  exit 1
fi
if ! grep -qx "Deployment successful" "$SANDBOX/output.txt" || ! grep -qx "Version: 1.4.2" "$SANDBOX/output.txt"; then
  echo "❌ output.txt was not written by deploy.sh (run the script instead of creating the file)"
  exit 1
fi
if ! grep -q "^Started as: .*deploy\.sh$" "$SANDBOX/output.txt" || grep -qx "Started as: deploy.sh" "$SANDBOX/output.txt"; then
  echo "❌ deploy.sh was not started as a program: run it as ./deploy.sh (not with bash deploy.sh)"
  exit 1
fi
echo "✅ deploy.sh is executable (mode $MODE) and ran successfully"
exit 0
