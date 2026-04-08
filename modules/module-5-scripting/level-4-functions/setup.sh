#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/deploy.sh" <<'SCRIPT'
#!/bin/bash
echo "Deploying api"
echo "api ready"
echo "Deploying web"
echo "web ready"
echo "Deploying worker"
echo "worker ready"
SCRIPT

chmod +x "$SANDBOX/deploy.sh"
