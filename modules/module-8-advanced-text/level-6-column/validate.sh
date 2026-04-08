#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/table.txt" ]; then
  echo "❌ FAIL: table.txt not found"
  exit 1
fi

NORMALIZED="$(awk '{$1=$1; print}' "$SANDBOX/table.txt")"
EXPECTED=$'NAME STATUS PORT\napi healthy 8080\nworker degraded 9090\ncache healthy 6379'
if [ "$NORMALIZED" != "$EXPECTED" ]; then
  echo "❌ FAIL: table.txt does not preserve the report data correctly"
  exit 1
fi

if grep -Eq '[[:space:]]{2,}|\t' "$SANDBOX/table.txt"; then
  echo "✅ PASS: table.txt is aligned and preserves the report rows"
  exit 0
fi

echo "❌ FAIL: table.txt should use aligned spacing between columns"
exit 1
