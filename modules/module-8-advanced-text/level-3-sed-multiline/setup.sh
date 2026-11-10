#!/bin/bash
# Config Injector: three nginx server blocks all have a "# EXTRA CONFIG"
# marker; only the 8443 block gets the include. A nested location { } closes
# with "    }" before the marker, which trips a naive /listen 8443/,/}/ range.
SANDBOX="$1"

cat > "$SANDBOX/app.conf" <<'EOF'
# myapp nginx site -- deployed by config management
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
}
EOF
