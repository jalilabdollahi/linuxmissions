#!/bin/bash
# outside_sessions.txt must equal the remote sessions of capture/utmp whose
# host is outside 10.0.0.0/8, as "user tty host", in utmp order.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/expected ] && [ -s capture/utmp ] || { echo "❌ the capture is gone; type 'reset'"; exit 1; }
[ -f outside_sessions.txt ] || { echo "❌ outside_sessions.txt does not exist yet"; exit 1; }
got=$(tr -d '\r' < outside_sessions.txt | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//' | grep -v '^$')
want=$(cat .lm-state/expected)
if [ "$got" = "$want" ]; then
  echo "✅ $(echo "$want" | wc -l | tr -d ' ') outside sessions listed correctly"; exit 0
fi
if [ -z "$got" ]; then echo "❌ outside_sessions.txt is empty"; exit 1; fi
if printf '%s\n' "$got" | grep -q '[()]'; then
  echo "❌ the host should be written without parentheses"; exit 1
fi
while read -r u t h; do
  [ -z "$h" ] && { echo "❌ a line has fewer than three fields; expected user tty host"; exit 1; }
done <<< "$got"
extra=$(comm -13 <(echo "$want" | sort) <(echo "$got" | sort) | head -1)
miss=$(comm -23 <(echo "$want" | sort) <(echo "$got" | sort) | wc -l | tr -d ' ')
if [ -n "$extra" ]; then
  echo "❌ '$extra' is not an outside session of the capture (wrong host, or a session from 10.0.0.0/8)"
elif [ "$miss" -gt 0 ]; then
  echo "❌ $miss outside session(s) missing from outside_sessions.txt"
else
  echo "❌ the right lines are there, but not in the order who lists them (or a line is duplicated)"
fi
exit 1
