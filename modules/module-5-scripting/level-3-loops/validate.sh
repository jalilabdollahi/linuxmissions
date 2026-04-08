#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/rename.sh" ]; then
  echo "❌ FAIL: rename.sh not found"
  exit 1
fi

bash "$SANDBOX/rename.sh" "$SANDBOX/incoming" >/dev/null 2>&1

if [ -f "$SANDBOX/incoming/a.txt" ] || [ -f "$SANDBOX/incoming/b.txt" ] || [ -f "$SANDBOX/incoming/c.txt" ]; then
  echo "❌ FAIL: Some .txt files were not renamed"
  exit 1
fi

if [ -f "$SANDBOX/incoming/a.bak" ] && [ -f "$SANDBOX/incoming/b.bak" ] && [ -f "$SANDBOX/incoming/c.bak" ] && [ -f "$SANDBOX/incoming/notes.md" ]; then
  echo "✅ PASS: rename.sh renamed all target files"
  exit 0
fi

echo "❌ FAIL: Expected .bak files were not created correctly"
exit 1
