#!/bin/bash
SANDBOX="$1"
FILE="$SANDBOX/app.conf"

if [ ! -f "$FILE" ]; then
  echo "❌ app.conf not found"
  exit 1
fi

# The original file with the include placed right after the marker of the 8443 block.
EXPECTED='# myapp nginx site -- deployed by config management
server {
    listen 80;
    server_name shop.example.com;
    # EXTRA CONFIG
    return 301 https://$host$request_uri;
}

server {
    listen 8443 ssl;
    server_name shop.example.com;
    ssl_certificate     /etc/ssl/shop.crt;
    ssl_certificate_key /etc/ssl/shop.key;

    location /static/ {
        root /srv/myapp;
        expires 7d;
    }

    # EXTRA CONFIG
@@INCLUDE@@
    location / {
        proxy_pass http://127.0.0.1:8080;
    }
}

server {
    listen 9000;
    server_name admin.internal;
    # EXTRA CONFIG
    allow 10.0.0.0/8;
    deny all;
}'

INC_RE='^[[:space:]]*include[[:space:]]+/etc/myapp/extra\.conf;[[:space:]]*$'
count="$(grep -Ec "$INC_RE" "$FILE")"
if [ "$count" -eq 0 ]; then
  if grep -q 'include /etc/myapp/extra.conf' "$FILE"; then
    echo "❌ the include line is there but not as 'include /etc/myapp/extra.conf;' (nginx directives end with ;)"
  else
    echo "❌ app.conf has no include line yet"
  fi
  exit 1
fi
if [ "$count" -gt 1 ]; then
  echo "❌ the include line appears $count times; only the server block on port 8443 should get it"
  exit 1
fi

ACTUAL="$(tr -d '\r' < "$FILE" | sed -E "s|$INC_RE|@@INCLUDE@@|")"
if [ "$ACTUAL" = "$EXPECTED" ]; then
  echo "✅ the include sits right after # EXTRA CONFIG in the 8443 block and nothing else changed"
  exit 0
fi
if [ "$(printf '%s\n' "$ACTUAL" | grep -v '@@INCLUDE@@')" != "$(printf '%s\n' "$EXPECTED" | grep -v '@@INCLUDE@@')" ]; then
  echo "❌ other lines of app.conf were changed or lost; only one line should be added"
else
  echo "❌ the include line is in the wrong place: it belongs directly after # EXTRA CONFIG in the listen 8443 block"
fi
exit 1
