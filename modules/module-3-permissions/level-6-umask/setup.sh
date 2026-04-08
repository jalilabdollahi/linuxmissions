#!/bin/bash
SANDBOX="$1"
echo "Current umask: $(umask)" > "$SANDBOX/hint.txt"
echo "Files start as 666, dirs start as 777." >> "$SANDBOX/hint.txt"
echo "umask is subtracted (bitwise AND with complement)." >> "$SANDBOX/hint.txt"
