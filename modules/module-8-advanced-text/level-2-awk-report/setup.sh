#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/expenses.csv" <<'EOF'
category,amount
travel,120
software,80
travel,45
food,30
software,20
food,10
EOF
