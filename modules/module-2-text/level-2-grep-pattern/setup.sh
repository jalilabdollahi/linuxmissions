#!/bin/bash
SANDBOX="$1"
cat > "$SANDBOX/app.log" << 'EOF'
2024-01-01 INFO  Service started
2024-01-01 INFO  Config loaded
2024-01-01 WARN  Slow response: 2400ms
2024-01-01 INFO  Request processed
2024-01-01 ERROR Database connection lost
2024-01-01 INFO  Retrying connection
2024-01-01 ERROR Retry failed
2024-01-01 INFO  Request queued
2024-01-01 FATAL Out of memory
2024-01-01 ERROR Cannot allocate buffer
2024-01-01 INFO  Graceful shutdown initiated
EOF
