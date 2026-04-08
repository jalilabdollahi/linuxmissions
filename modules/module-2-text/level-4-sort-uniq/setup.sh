#!/bin/bash
SANDBOX="$1"
cat > "$SANDBOX/access.log" << 'EOF'
192.168.1.10 GET /api
10.0.0.5 GET /health
192.168.1.10 POST /api
192.168.1.20 GET /api
192.168.1.10 GET /api
10.0.0.5 GET /health
192.168.1.30 GET /api
10.0.0.5 GET /health
10.0.0.5 GET /health
192.168.1.10 DELETE /api
192.168.1.20 GET /api
192.168.1.10 GET /api
EOF
