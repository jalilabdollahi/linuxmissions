#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

TOKEN=$(sed -n 's/^AUTH_TOKEN=//p' .config/app/.credentials 2>/dev/null | head -n 1)
if [ -z "$TOKEN" ]; then
  echo "❌ the credentials file was moved or changed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f token.txt ]; then
  echo "❌ token.txt does not exist in the sandbox root"
  exit 1
fi

ANSWER=$(tr -d '\r' < token.txt | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$')
case "$ANSWER" in
  "$TOKEN")
    echo "✅ token.txt holds the real AUTH_TOKEN"; exit 0 ;;
  "AUTH_TOKEN=$TOKEN")
    echo "❌ right token, but token.txt should hold only the value, without 'AUTH_TOKEN='" ;;
  *paste-your-token-here*)
    echo "❌ that is the placeholder from .env.example; the real token is elsewhere" ;;
  *)
    echo "❌ token.txt does not contain the real AUTH_TOKEN value" ;;
esac
exit 1
