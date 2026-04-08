#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/app.conf" <<'EOF'
server {
  listen 8080;
  # EXTRA CONFIG
  root /srv/app;
}
EOF
