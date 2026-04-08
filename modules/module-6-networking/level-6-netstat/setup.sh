#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/connections.txt" <<'EOF'
State Recv-Q Send-Q Local Address:Port Peer Address:Port
ESTAB 0      0      10.0.0.44:22     10.0.0.10:55210
ESTAB 0      0      10.0.0.44:443    10.0.0.10:55211
ESTAB 0      0      10.0.0.44:5432   10.0.0.25:43100
ESTAB 0      0      10.0.0.44:8080   10.0.0.99:39010
TIME-WAIT 0   0      10.0.0.44:80    10.0.0.77:50000
EOF
