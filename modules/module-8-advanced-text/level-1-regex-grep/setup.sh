#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/app.log" <<'EOF'
client=10.1.1.5 user=alice action=login
client=172.16.0.44 user=bob action=upload
note no ip here
proxy=192.168.1.200 target=api
EOF
