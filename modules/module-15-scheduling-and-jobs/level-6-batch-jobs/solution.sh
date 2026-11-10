#!/bin/bash
export PATH="$SANDBOX/bin:$PATH"
cd app || exit 1
export DATA_DIR="$SANDBOX/data"
echo './reindex.sh' | batch
atq
at -c "$(atq | awk '{print $1}')" | grep -E '^DATA_DIR=|^cd '
