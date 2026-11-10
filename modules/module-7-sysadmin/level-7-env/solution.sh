#!/bin/bash
# Try it first: ./start.sh  (shows the errors from sourcing .env)
cat > .env <<'ENV'
# myapp settings -- read by start.sh
export APP_MODE=production
export APP_PORT=8080
export APP_NAME="My Shop"
ENV
./start.sh
