#!/bin/bash
# warn_users.txt = users with some session idle < 10 minutes, sorted, unique.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/expected ] && [ -s capture/w.txt ] || { echo "❌ the capture is gone; type 'reset'"; exit 1; }
[ -f warn_users.txt ] || { echo "❌ warn_users.txt does not exist yet"; exit 1; }
got=$(tr -d '\r' < warn_users.txt | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$')
want=$(cat .lm-state/expected)
[ -n "$got" ] || { echo "❌ warn_users.txt is empty"; exit 1; }
if [ "$got" = "$want" ]; then
  echo "✅ $(echo "$want" | wc -l | tr -d ' ') active users will be warned"; exit 0
fi
if [ "$(echo "$got" | sort -u)" = "$want" ]; then
  echo "❌ the names are right, but a user is listed twice or the list is not sorted"; exit 1
fi
extra=$(comm -13 <(echo "$want") <(echo "$got" | sort -u) | head -1)
miss=$(comm -23 <(echo "$want") <(echo "$got" | sort -u) | wc -l | tr -d ' ')
if [ -n "$extra" ]; then
  echo "❌ $extra has no session idle for under 10 minutes (look at the unit in the IDLE column: 1:05m is not 1 minute)"
else
  echo "❌ $miss active user(s) missing; a user with several sessions counts if any session is recent"
fi
exit 1
