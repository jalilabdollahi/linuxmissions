#!/bin/bash
# Fill the Template, Spare nginx: deploy.env defines APP_HOST and APP_PORT (random per
# run, not exported). The template uses both $APP_HOST and ${APP_PORT} several times
# next to nginx variables. The expected output is rendered with sed so the validator
# does not depend on envsubst behaving.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

host="app-0$((1 + RANDOM % 9)).internal"
port=$((8100 + RANDOM % 800))
cat > deploy.env <<CONF
# deployment values for this release
APP_HOST=$host
APP_PORT=$port
CONF

cat > nginx.conf.tmpl <<'CONF'
# nginx.conf - rendered by deploy from nginx.conf.tmpl
upstream app {
    server $APP_HOST:${APP_PORT} max_fails=3;
}

map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen 80;
    server_name $APP_HOST;
    access_log /var/log/nginx/app.log combined;

    location / {
        proxy_pass http://app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
    }

    location /old {
        return 301 http://$APP_HOST:${APP_PORT}$request_uri;
    }

    # served by $APP_HOST on port ${APP_PORT}
}
CONF
cp nginx.conf.tmpl .lm-state/tmpl

sed -e 's/\${APP_PORT}/'"$port"'/g' -e 's/\$APP_HOST/'"$host"'/g' nginx.conf.tmpl > .lm-state/expected.conf
cp deploy.env .lm-state/deploy.env
