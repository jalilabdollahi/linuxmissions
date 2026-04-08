#!/bin/bash
SANDBOX="$1"
cat > "$SANDBOX/access.log" << 'EOF'
192.168.1.10 GET /api/users 1024
192.168.1.20 POST /api/login 256
192.168.1.10 GET /api/data 2048
10.0.0.5 GET /health 64
192.168.1.30 GET /api/users 1024
10.0.0.5 GET /health 64
192.168.1.20 DELETE /api/session 128
192.168.1.10 GET /api/users 1024
192.168.1.40 GET /api/metrics 512
10.0.0.5 GET /health 64
EOF
