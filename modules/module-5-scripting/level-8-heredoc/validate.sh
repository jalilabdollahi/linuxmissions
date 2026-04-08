#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/generate.sh" ]; then
  echo "❌ FAIL: generate.sh not found"
  exit 1
fi

if ! grep -q '<<' "$SANDBOX/generate.sh"; then
  echo "❌ FAIL: generate.sh should use a heredoc"
  exit 1
fi

(cd "$SANDBOX" && bash ./generate.sh >/dev/null 2>&1)

if [ ! -f "$SANDBOX/app.conf" ]; then
  echo "❌ FAIL: app.conf was not generated"
  exit 1
fi

if grep -q '^name=linuxmissions$' "$SANDBOX/app.conf" && grep -q '^port=9090$' "$SANDBOX/app.conf" && grep -q '^environment=production$' "$SANDBOX/app.conf"; then
  echo "✅ PASS: app.conf was generated from vars.env"
  exit 0
fi

echo "❌ FAIL: app.conf does not contain the expected values"
exit 1
