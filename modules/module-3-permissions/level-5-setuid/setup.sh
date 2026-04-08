#!/bin/bash
SANDBOX="$1"
mkdir -p "$SANDBOX/bin" "$SANDBOX/lib" "$SANDBOX/etc"
# Normal files
touch "$SANDBOX/bin/normalcmd"
touch "$SANDBOX/lib/libfoo.so"
touch "$SANDBOX/etc/config.conf"
chmod 755 "$SANDBOX/bin/normalcmd"

# SUID file
touch "$SANDBOX/bin/special_tool"
chmod 4755 "$SANDBOX/bin/special_tool"

# SGID file
touch "$SANDBOX/bin/group_tool"
chmod 2755 "$SANDBOX/bin/group_tool"

# Normal binary
touch "$SANDBOX/bin/ordinary"
chmod 755 "$SANDBOX/bin/ordinary"
