#!/bin/bash
SANDBOX="$1"
cat > "$SANDBOX/access.log" << 'EOF'
10.0.1.1 GET /api/items
10.0.1.2 POST /api/items
10.0.1.1 GET /api/items
10.0.1.3 POST /api/login
10.0.1.2 POST /api/items
10.0.1.1 POST /api/items
10.0.1.3 GET /api/items
10.0.1.2 POST /api/orders
10.0.1.1 GET /api/orders
10.0.1.3 POST /api/items
10.0.1.2 POST /api/items
10.0.1.1 POST /api/login
EOF
