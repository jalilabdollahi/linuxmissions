#!/bin/bash
# root-login-hosts.txt = exactly the hosts whose first PermitRootLogin is yes.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/yes ] || [ ! -s .lm-state/why ]; then
  echo "❌ the level's reference data in .lm-state/ is gone; type 'reset'"
  exit 1
fi
if [ ! -f root-login-hosts.txt ]; then
  echo "❌ root-login-hosts.txt does not exist yet"
  exit 1
fi
GOT=$(tr -d '\r' < root-login-hosts.txt | sed -e 's/[[:space:]]*$//' -e 's/^[[:space:]]*//' | grep -v '^$' | LC_ALL=C sort)
WANT=$(cat .lm-state/yes)
if [ "$GOT" = "$WANT" ]; then
  echo "✅ root-login-hosts.txt names the $(printf '%s\n' "$WANT" | wc -l | tr -d ' ') hosts that really allow root password logins"
  exit 0
fi
if [ -z "$GOT" ]; then
  echo "❌ root-login-hosts.txt is empty"
  exit 1
fi
if [ -n "$(printf '%s\n' "$GOT" | uniq -d)" ]; then
  echo "❌ root-login-hosts.txt lists a host more than once"
  exit 1
fi
while IFS= read -r h; do
  printf '%s\n' "$WANT" | grep -qxF -- "$h" && continue
  why=$(awk -F'\t' -v h="$h" '$1 == h { print $2 }' .lm-state/why)
  if [ -n "$why" ]; then
    echo "❌ $h does not allow root password logins: $why"
  else
    echo "❌ '$h' is not a host name; write the folder names under hosts/, like web-01"
  fi
  exit 1
done <<< "$GOT"
missing=$(printf '%s\n' "$WANT" | grep -cvxF -f <(printf '%s\n' "$GOT"))
echo "❌ $missing host(s) that allow root password logins are missing (keywords are case-insensitive and may be indented)"
exit 1
