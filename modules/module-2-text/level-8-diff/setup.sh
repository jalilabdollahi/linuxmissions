#!/bin/bash
SANDBOX="$1"
cat > "$SANDBOX/v1.conf" << 'EOF'
host=localhost
port=8080
workers=2
debug=true
log_level=verbose
timeout=30
EOF
cat > "$SANDBOX/v2.conf" << 'EOF'
host=prod.example.com
port=443
workers=8
debug=false
log_level=error
timeout=30
max_connections=1000
EOF
