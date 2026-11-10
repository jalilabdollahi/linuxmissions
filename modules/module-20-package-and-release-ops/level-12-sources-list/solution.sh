#!/bin/bash
export PATH="$SANDBOX/bin:$PATH"
cd rootfs/etc/apt
apt-get update 2>&1 | grep -E '^(W|E):'
typo=$(cat "$SANDBOX/.lm/typo")   # (the player reads it from the error message)
sed -i "s/ $typo / noble-updates /" sources.list.d/ubuntu.sources
: > sources.list
key=$(grep -o 'signed-by=[^] ]*' sources.list.d/vendor.list | cut -d= -f2)
cat > sources.list.d/vendor.sources <<SRC
Types: deb
URIs: $(grep -o 'file:[^ ]*' sources.list.d/vendor.list)
Suites: stable
Components: main
Signed-By: $key
SRC
rm sources.list.d/vendor.list
cd "$SANDBOX"
apt-get update 2>&1 | grep -E '^(W|E):' || echo clean
