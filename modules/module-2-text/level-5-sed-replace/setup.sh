#!/bin/bash
SANDBOX="$1"
cat > "$SANDBOX/config.conf" << 'EOF'
db_host=staging.internal
api_host=staging.internal
cache_host=staging.internal
backup_host=staging.internal
log_host=staging.internal
environment=staging
EOF
