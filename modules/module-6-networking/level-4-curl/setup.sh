#!/bin/bash
SANDBOX="$1"

mkdir -p "$SANDBOX/api"
cat > "$SANDBOX/api/response.json" <<'EOF'
{
  "service": {
    "name": "metrics-api",
    "status": "healthy"
  }
}
EOF
