#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
SECRET="$SANDBOX/var/lib/billing/state/vault/secret.conf"

if [ ! -f "$SECRET" ]; then
  echo "❌ secret.conf was moved or deleted; type 'reset' to restore the sandbox"
  exit 1
fi
CODE=$(sed -n 's/^access_code=//p' "$SECRET" | head -n 1)

if [ ! -f "$SANDBOX/answer.txt" ]; then
  other=$(cd "$SANDBOX" && find . -name answer.txt -type f 2>/dev/null | head -n 1)
  if [ -n "$other" ]; then
    echo "❌ answer.txt is at $other, but it must be in the sandbox root (cd \"\$SANDBOX\")"
  else
    echo "❌ answer.txt not found in the sandbox root"
  fi
  exit 1
fi

ANSWER=$(tr -d '\r' < "$SANDBOX/answer.txt" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$')
if [ "$ANSWER" = "$CODE" ]; then
  echo "✅ answer.txt holds the right access code"
  exit 0
fi
if [ "$ANSWER" = "access_code=$CODE" ]; then
  echo "❌ answer.txt should hold only the value, without 'access_code='"
  exit 1
fi
case "$ANSWER" in
  CHANGE_ME|EXPIRED-2019) echo "❌ that code comes from a look-alike file; you need the one named exactly secret.conf" ;;
  *) echo "❌ answer.txt does not contain the access code from secret.conf" ;;
esac
exit 1
