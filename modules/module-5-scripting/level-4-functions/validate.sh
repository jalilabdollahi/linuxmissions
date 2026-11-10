#!/bin/bash
# Runs deploy.sh in a scratch copy of the project, then loads it and calls
# deploy_service for a service the original script never knew about.
SANDBOX="$1"
SCRIPT="$SANDBOX/deploy.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ deploy.sh is missing (type reset to get it back)"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/build" "$WORK/releases"
for svc in api web worker billing; do
  echo "$svc build $RANDOM" > "$WORK/build/$svc.tar"
done
cp "$SCRIPT" "$WORK/deploy.sh"

LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"

# 1. Same behaviour as before.
out="$(cd "$WORK" && $LIMIT bash ./deploy.sh </dev/null 2>/dev/null | tr -d '\r')"
expected=$'==> Deploying api\napi ready\n==> Deploying web\nweb ready\n==> Deploying worker\nworker ready'
if [ "$out" != "$expected" ]; then
  echo "❌ bash deploy.sh no longer prints the same 6 lines as the original script"
  exit 1
fi
for svc in api web worker; do
  if ! cmp -s "$WORK/build/$svc.tar" "$WORK/releases/$svc.tar"; then
    echo "❌ bash deploy.sh did not copy build/$svc.tar to releases/$svc.tar"
    exit 1
  fi
done
if [ -e "$WORK/releases/billing.tar" ]; then
  echo "❌ bash deploy.sh deployed services other than api, web and worker"
  exit 1
fi

# 2. The function exists.
if ! (cd "$WORK" && $LIMIT bash -c 'source ./deploy.sh >/dev/null 2>&1; declare -F deploy_service >/dev/null' </dev/null); then
  echo "❌ deploy.sh does not define a function called deploy_service"
  exit 1
fi

# 3. The function takes the service name as an argument.
rm -f "$WORK"/releases/*
out="$(cd "$WORK" && $LIMIT bash -c 'source ./deploy.sh >/dev/null 2>&1; deploy_service billing' </dev/null 2>/dev/null | tr -d '\r')"
if [ "$out" != $'==> Deploying billing\nbilling ready' ]; then
  echo "❌ deploy_service billing printed '$(echo "$out" | head -1)...', expected '==> Deploying billing' and 'billing ready'"
  exit 1
fi
if ! cmp -s "$WORK/build/billing.tar" "$WORK/releases/billing.tar"; then
  echo "❌ deploy_service billing did not copy build/billing.tar to releases/billing.tar"
  exit 1
fi

# 4. The copy-pasted blocks are gone.
copies="$(grep -v '^[[:space:]]*#' "$SCRIPT" | grep -c 'ready')"
if [ "$copies" -gt 1 ]; then
  echo "❌ deploy.sh still has a separate block for each service ($copies lines print 'ready'); let the function do it"
  exit 1
fi

echo "✅ deploy.sh is driven by one deploy_service function and behaves as before"
exit 0
