#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/report.txt" <<'EOF'
NAME STATUS PORT
api healthy 8080
worker degraded 9090
cache healthy 6379
EOF
