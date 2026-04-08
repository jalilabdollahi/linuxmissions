#!/bin/bash
SANDBOX="$1"
mkdir -p "$SANDBOX/app/"{config,data,scripts}
# Normal files
echo "safe" > "$SANDBOX/app/config/db.conf"
chmod 644 "$SANDBOX/app/config/db.conf"
echo "safe" > "$SANDBOX/app/scripts/start.sh"
chmod 755 "$SANDBOX/app/scripts/start.sh"
# World-writable files (bad!)
echo "bad" > "$SANDBOX/app/config/app.conf"
chmod 666 "$SANDBOX/app/config/app.conf"
echo "bad" > "$SANDBOX/app/data/cache.dat"
chmod 777 "$SANDBOX/app/data/cache.dat"
echo "bad" > "$SANDBOX/app/data/session.dat"
chmod 666 "$SANDBOX/app/data/session.dat"
