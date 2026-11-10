#!/bin/bash
# Five config files with two mistakes each, except hosts with one: app.ini ("workers 4" without
# "=", port with a "/tcp" suffix), app.env (spaces around "=", APP_ENV=prod), features.json
# (trailing comma, then the same key twice), services.yml (a TAB, a port as string), hosts (a
# mistyped IP). The port and version are random; the checker reports one error at a time.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p etc/app bin run .lm-state

free_port() {
  local p
  while :; do
    p=$((RANDOM % 9000 + 20000))
    python3 -c "import socket,sys; s=socket.socket(); s.bind(('127.0.0.1',$p))" 2>/dev/null && { echo "$p"; return; }
  done
}
PORT=$(free_port)
VER="$((RANDOM % 4 + 3)).$((RANDOM % 9)).$((RANDOM % 9))"
KEY=$(head -c 18 /dev/urandom | base64 | tr -d '\n')
printf '%s\n' "$PORT" > .lm-state/port
printf '%s\n' "$VER" > .lm-state/version
printf '%s\n' "$KEY" > .lm-state/secret

cat > etc/app/app.ini <<INI
; app.ini - migrated from app.cfg
[server]
host = 127.0.0.1
port = $PORT/tcp
workers 4

[database]
url = postgres://app:s3cret@db.local:5432/app
pool_size = 10

[logging]
level = info
INI
cat > etc/app/app.env <<ENV
# app.env - environment of the service
APP_ENV=prod
APP_VERSION = $VER
SECRET_KEY=$KEY
LOG_COLOR=1
ENV
cat > etc/app/features.json <<'JSON'
{
  "features": {
    "search": true,
    "checkout": true,
    "beta_ui": false,
    "checkout": false,
  }
}
JSON
printf 'services:\n  cache:\n    host: 127.0.0.1\n    port: "6379"\n  queue:\n\thost: 127.0.0.1\n    port: 5672\n' > etc/app/services.yml
cat > etc/app/hosts <<'HOSTS'
127.0.0.1 localhost
127.0.01 db.local cache.local
HOSTS
cat > MIGRATION.txt <<TXT
Migration notes - app 3.x -> 4.x config format. These are the values the app must run with.

  app.ini        server: host 127.0.0.1, port $PORT, workers 4
                 database: url unchanged, pool_size 10; logging: level info
  app.env        APP_ENV=production, APP_VERSION=$VER, SECRET_KEY unchanged
  features.json  search on, checkout ON (it must stay enabled), beta_ui off
  services.yml   cache 127.0.0.1:6379 and queue 127.0.0.1:5672 (ports are numbers)
  hosts          db.local and cache.local are this machine (127.0.0.1)

Check with: bin/app --check-config      Start with: bin/app start      Then: curl http://127.0.0.1:$PORT/
TXT

cp "$HERE/app.py" bin/app
chmod 755 bin/app
