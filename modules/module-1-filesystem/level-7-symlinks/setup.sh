#!/bin/bash
SANDBOX="$1"
mkdir -p "$SANDBOX/etc/myapp/v1" "$SANDBOX/etc/myapp/v2"
echo "version=1" > "$SANDBOX/etc/myapp/v1/config.conf"
echo "version=2" > "$SANDBOX/etc/myapp/v2/config.conf"
# active.conf does NOT exist yet — player must create the symlink
