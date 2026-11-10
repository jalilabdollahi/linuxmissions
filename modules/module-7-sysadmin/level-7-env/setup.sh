#!/bin/bash
# Env Surgery: start.sh sources .env and then execs app.sh. The .env file has
# three classic bugs: spaces around =, an unquoted value with a space, and no
# export (so the child process app.sh never sees the variables).
SANDBOX="$1"
cd "$SANDBOX" || exit 1

cat > .env <<'EOF'
# myapp settings -- read by start.sh
APP_MODE = production
APP_PORT=8080
APP_NAME=My Shop
EOF

cat > start.sh <<'EOF'
#!/bin/bash
# Do not edit: this is what the service manager runs.
cd "$(dirname "$0")" || exit 1
. ./.env
exec ./app.sh
EOF

cat > app.sh <<'EOF'
#!/bin/bash
for var in APP_MODE APP_PORT APP_NAME; do
  if [ -z "$(printenv "$var")" ]; then
    echo "app.sh: missing environment variable $var" >&2
    exit 1
  fi
done
echo "$APP_NAME ready on :$APP_PORT in $APP_MODE mode"
EOF
chmod +x start.sh app.sh
