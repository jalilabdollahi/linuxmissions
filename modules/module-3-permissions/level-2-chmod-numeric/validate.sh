#!/bin/bash
SANDBOX="$1"
FAIL=0

check_perm() {
  local file="$1" expected="$2"
  local actual
  actual=$(stat -c "%a" "$file" 2>/dev/null)
  if [ "$actual" = "$expected" ]; then
    echo "✅ $(basename $file): $actual"
  else
    echo "❌ $(basename $file): got $actual, expected $expected"
    FAIL=1
  fi
}

check_perm "$SANDBOX/index.html" "644"
check_perm "$SANDBOX/app.py" "755"
check_perm "$SANDBOX/secrets.conf" "600"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
