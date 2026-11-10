#!/bin/bash
SANDBOX="$1"
FILE="$SANDBOX/report.txt"

if [ ! -f "$FILE" ]; then
  echo "❌ report.txt not found"
  exit 1
fi

WANT_OWNER='owner=platform-ops@example.com'
WANT_ACTIVE='active=worker,scheduler,mailer,cache-warmer,thumbnailer,auth,exporter,importer,notifier,audit-log,geoip,pdf-render,recommender,inventory,pricing,shipping,returns,loyalty'

LINES="$(tr -d '\r' < "$FILE" | sed -e 's/[[:space:]]*$//' -e '/^$/d')"
if [ "$LINES" = "$WANT_OWNER
$WANT_ACTIVE" ]; then
  echo "✅ report.txt has the owner's e-mail and the 18 active services in order"
  exit 0
fi

if printf '%s\n' "$LINES" | grep -q '"'; then
  echo "❌ report.txt contains JSON quotes; ask jq for raw strings"
  exit 1
fi
if [ "$(printf '%s\n' "$LINES" | grep -c .)" -ne 2 ]; then
  echo "❌ report.txt should have exactly two lines: owner=... and active=..."
  exit 1
fi
if [ "$(printf '%s\n' "$LINES" | sed -n 1p)" != "$WANT_OWNER" ]; then
  echo "❌ the first line should be owner=<the e-mail address from the owner's contacts>"
  exit 1
fi
got="$(printf '%s\n' "$LINES" | sed -n 2p)"
case "$got" in
  active=*) ;;
  *) echo "❌ the second line should start with active="; exit 1 ;;
esac
n="$(printf '%s' "${got#active=}" | tr ',' '\n' | grep -c .)"
if printf '%s' "$got" | grep -Eq 'billing|gateway|ledger|cart|chat-bot|reports|api,|=api'; then
  echo "❌ active= lists services that are not active (inactive, or with no active flag at all)"
elif [ "$n" -ne 18 ]; then
  echo "❌ active= lists $n services; the number of active ones is different"
else
  echo "❌ active= must list the active services comma-separated, no spaces, in file order"
fi
exit 1
