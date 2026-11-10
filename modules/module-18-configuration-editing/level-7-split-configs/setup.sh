#!/bin/bash
# One Site per File: seven server blocks, built from separate pieces so the
# expected output files are known exactly. One block has a nested location
# block and an inner "}" at the same indentation as a real one, one lists
# three names on its server_name line.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state/expected

e=.lm-state/expected
cat > $e/00-header.conf <<'CONF'
# sites.conf - public virtual hosts of web-01
# maintained by the platform team; one server block per site
CONF
cat > $e/www.example.com.conf <<'CONF'
server {
    listen 80;
    server_name www.example.com;
    root /srv/www/main;
    index index.html;
}
CONF
cat > $e/shop.example.com.conf <<'CONF'
server {
    listen 80;
    server_name shop.example.com www.shop.example.com store.example.com;
    root /srv/www/shop;
    location /cart {
        proxy_pass http://127.0.0.1:9100;
        proxy_set_header Host $host;
    }
    location /assets {
        expires 30d;
    }
}
CONF
cat > $e/blog.example.com.conf <<'CONF'
server {
    listen 80;
    server_name blog.example.com;
    root /srv/www/blog;
    # comments with braces { do not count
    location ~ \.php$ {
        fastcgi_pass unix:/run/php/blog.sock;
    }
}
CONF
cat > $e/api.example.com.conf <<'CONF'
server {
    listen 443 ssl;
    server_name api.example.com;
    ssl_certificate /etc/ssl/api.pem;
    location /v1/ {
        proxy_pass http://127.0.0.1:9200;
        limit_except GET {
            deny all;
        }
    }
}
CONF
cat > $e/docs.example.com.conf <<'CONF'
server {
    listen 80;
    server_name docs.example.com;
    root /srv/www/docs;
    autoindex on;
}
CONF
cat > $e/status.example.com.conf <<'CONF'
server {
    listen 127.0.0.1:8081;
    server_name status.example.com;
    location /nginx_status {
        stub_status;
        allow 127.0.0.1;
        deny all;
    }
}
CONF
cat > $e/old.example.com.conf <<'CONF'
server {
    listen 80;
    server_name old.example.com;
    return 301 https://www.example.com$request_uri;
}
CONF

# Assemble the monolith: header, then the blocks in this order, one blank line apart.
{
  cat $e/00-header.conf
  for n in www shop blog api docs status old; do
    echo
    cat $e/$n.example.com.conf
  done
} > sites.conf
cp sites.conf .lm-state/sites.conf.orig
