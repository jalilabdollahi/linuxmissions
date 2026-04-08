#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/vars.env" <<'ENV'
APP_NAME=linuxmissions
APP_PORT=9090
APP_ENV=production
ENV

cat > "$SANDBOX/generate.sh" <<'SCRIPT'
#!/bin/bash
# TODO: source vars.env and generate app.conf with a heredoc
SCRIPT

chmod +x "$SANDBOX/generate.sh"
