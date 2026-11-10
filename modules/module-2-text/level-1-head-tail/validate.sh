#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -f app.log ] || [ "$(wc -l < app.log | tr -d ' ')" -ne 3000 ]; then
  echo "❌ app.log was changed or removed; type 'reset' to restore it"
  exit 1
fi

check() {  # file which-part expected-output
  if [ ! -f "$1" ]; then
    echo "❌ $1 does not exist yet"
    exit 1
  fi
  if [ "$(tr -d '\r' < "$1")" != "$3" ]; then
    n=$(wc -l < "$1" | tr -d ' ')
    echo "❌ $1 ($n lines) is not exactly the $2 5 lines of app.log"
    exit 1
  fi
}
check first5.txt first "$(head -n 5 app.log)"
check last5.txt last "$(tail -n 5 app.log)"
echo "✅ first5.txt and last5.txt hold the first and last 5 lines of app.log"
exit 0
