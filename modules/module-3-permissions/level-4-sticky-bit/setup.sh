#!/bin/bash
SANDBOX="$1"
mkdir -p "$SANDBOX/shared"
chmod 777 "$SANDBOX/shared"
touch "$SANDBOX/shared/alice_file.txt"
touch "$SANDBOX/shared/bob_file.txt"
# No sticky bit set — player must add it
