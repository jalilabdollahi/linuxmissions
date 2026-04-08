#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/app.env" <<'ENV'
APP_NAME=linuxmissions
APP_ENV=staging
APP_PORT=8080
ENV

cat > "$SANDBOX/load_env.sh" <<'SCRIPT'
#!/bin/bash
# TODO: read key=value lines from $1 and export them
SCRIPT

chmod +x "$SANDBOX/load_env.sh"
