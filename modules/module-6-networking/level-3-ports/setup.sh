#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/ss-output.txt" <<'EOF'
State  Recv-Q Send-Q Local Address:Port Peer Address:Port
LISTEN 0      128    127.0.0.1:5432   0.0.0.0:*
LISTEN 0      511    0.0.0.0:80       0.0.0.0:*
LISTEN 0      128    0.0.0.0:22       0.0.0.0:*
ESTAB  0      0      10.0.0.44:22     10.0.0.10:55210
LISTEN 0      128    0.0.0.0:8080     0.0.0.0:*
EOF
