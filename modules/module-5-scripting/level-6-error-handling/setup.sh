#!/bin/bash
SANDBOX="$1"

mkdir -p "$SANDBOX/deploy"
cat > "$SANDBOX/app.conf" <<'CONF'
# app.conf - production settings
# owner: platform team
listen=0.0.0.0:8080
workers=4
# keep this in sync with the load balancer
timeout=30
CONF
cp "$SANDBOX/app.conf" "$SANDBOX/shop settings.conf"

cat > "$SANDBOX/safe_copy.sh" <<'SCRIPT'
#!/bin/bash
# safe_copy.sh SOURCE_FILE
# Copy a config into deploy/app.conf, without its comment lines.

SOURCE_FILE=$1
grep -v '^#' $SOURCE_FILE | tr -d '\r' > deploy/app.conf
echo "copy complete"
SCRIPT

chmod +x "$SANDBOX/safe_copy.sh"
