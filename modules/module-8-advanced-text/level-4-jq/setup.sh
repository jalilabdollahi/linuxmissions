#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/data.json" <<'EOF'
{
  "owner": {
    "name": "Ops",
    "email": "ops@example.com"
  },
  "services": [
    {"name": "api", "active": true},
    {"name": "worker", "active": true},
    {"name": "batch", "active": false}
  ]
}
EOF
