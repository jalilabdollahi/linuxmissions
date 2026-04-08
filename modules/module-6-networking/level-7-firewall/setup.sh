#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/firewall.rules" <<'EOF'
-P INPUT ACCEPT
-A INPUT -p tcp --dport 22 -j ACCEPT
-A INPUT -p tcp --dport 80 -j ACCEPT
-A INPUT -p tcp --dport 443 -j ACCEPT
-A INPUT -p tcp --dport 3306 -j DROP
EOF
