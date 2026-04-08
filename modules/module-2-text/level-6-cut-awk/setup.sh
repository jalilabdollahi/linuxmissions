#!/bin/bash
SANDBOX="$1"
cat > "$SANDBOX/users.csv" << 'EOF'
alice,28,alice@example.com,admin,active
bob,34,bob@example.com,user,active
carol,25,carol@example.com,user,inactive
dave,41,dave@example.com,admin,active
eve,30,eve@example.com,user,active
EOF
