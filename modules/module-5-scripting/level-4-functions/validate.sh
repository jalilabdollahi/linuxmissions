#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/deploy.sh" ]; then
  echo "❌ FAIL: deploy.sh not found"
  exit 1
fi

CONTENT="$(cat "$SANDBOX/deploy.sh")"
OUTPUT="$(bash "$SANDBOX/deploy.sh" 2>/dev/null | tr -d '\r')"

if ! printf '%s' "$CONTENT" | grep -Eq 'deploy_service[[:space:]]*\(\)|function[[:space:]]+deploy_service'; then
  echo "❌ FAIL: deploy.sh should define a deploy_service function"
  exit 1
fi

EXPECTED=$'Deploying api\napi ready\nDeploying web\nweb ready\nDeploying worker\nworker ready'
if [ "$OUTPUT" = "$EXPECTED" ]; then
  echo "✅ PASS: deploy.sh uses a function and keeps the correct behavior"
  exit 0
fi

echo "❌ FAIL: deploy.sh output is not correct"
exit 1
