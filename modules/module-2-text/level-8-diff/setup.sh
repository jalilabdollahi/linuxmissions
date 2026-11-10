#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

cat > v1.conf <<'CONF'
# shop-api configuration, release 4.1
[server]
host=0.0.0.0
port=8080
workers=4
keepalive_timeout=65
max_body_size=1m
gzip=on

[database]
host=db-primary.internal
port=5432
name=shop
user=shop_app
pool_size=10
pool_timeout=30
ssl=prefer

[cache]
backend=redis
host=cache.internal
port=6379
ttl=300

[logging]
level=debug
format=text
file=/var/log/shop-api/app.log
rotate=daily

[features]
new_checkout=false
recommendations=true
legacy_coupons=true
CONF

cat > v2.conf <<'CONF'
# shop-api configuration, release 4.2
[server]
host=0.0.0.0
port=8443
workers=8
keepalive_timeout=65
max_body_size=1m
gzip=on

[database]
host=db-primary.internal
port=5432
name=shop
user=shop_app
pool_size=25
pool_timeout=30
ssl=require

[cache]
backend=redis
host=cache.internal
port=6379
ttl=300

[logging]
level=info
format=json
file=/var/log/shop-api/app.log
rotate=daily

[features]
new_checkout=true
recommendations=true
rate_limit_per_minute=600
CONF
