#!/bin/bash
SANDBOX="$1"

mkdir -p "$SANDBOX/build" "$SANDBOX/releases"
for svc in api web worker; do
  echo "$svc build 2026.11.10" > "$SANDBOX/build/$svc.tar"
done

cat > "$SANDBOX/deploy.sh" <<'SCRIPT'
#!/bin/bash
# deploy.sh - ship every service from build/ to releases/
# Each block below was copy-pasted from the one above it.

echo "==> Deploying api"
cp "build/api.tar" "releases/api.tar"
echo "api ready"

echo "==> Deploying web"
cp "build/web.tar" "releases/web.tar"
echo "web ready"

echo "==> Deploying worker"
cp "build/worker.tar" "releases/worker.tar"
echo "worker ready"
SCRIPT

chmod +x "$SANDBOX/deploy.sh"
