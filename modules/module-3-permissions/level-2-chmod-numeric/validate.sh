#!/bin/bash
SANDBOX="$1"
FAIL=0

mode_of() {
  stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"
}

check_mode() {
  local name="$1" want="$2" why="$3" got
  if [ ! -f "$SANDBOX/$name" ]; then
    echo "❌ $name is missing (type reset to get it back)"
    FAIL=1
    return
  fi
  got=$(mode_of "$SANDBOX/$name")
  if [ "$got" != "$want" ]; then
    echo "❌ $name is $got, which does not match: $why"
    FAIL=1
  fi
}

check_mode index.html   644 "everyone reads, only you write"
check_mode app.py       755 "everyone reads and runs, only you write"
check_mode secrets.conf 600 "only you read and write"

if [ "$FAIL" -eq 0 ]; then
  echo "✅ index.html 644, app.py 755, secrets.conf 600"
  exit 0
fi
exit 1
