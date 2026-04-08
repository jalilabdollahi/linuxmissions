#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
mkdir -p "$SANDBOX/var/app/config/prod/secrets"
echo "mission_complete=true" > "$SANDBOX/var/app/config/prod/secrets/secret.conf"
# Add decoys
mkdir -p "$SANDBOX/etc/nginx" "$SANDBOX/home/user/docs"
echo "nothing here" > "$SANDBOX/etc/nginx/nginx.conf"
echo "nope" > "$SANDBOX/home/user/docs/readme.txt"
