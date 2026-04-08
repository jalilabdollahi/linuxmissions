#!/bin/bash
SANDBOX="$1"
mkdir -p "$SANDBOX"/{a,b/c,d/e/f}
# Create .tmp files to delete
touch "$SANDBOX/a/job1.tmp" "$SANDBOX/a/job2.tmp"
touch "$SANDBOX/b/c/session.tmp"
touch "$SANDBOX/d/e/f/cache.tmp"
touch "$SANDBOX/root.tmp"
# Create keeper files
echo "keep me" > "$SANDBOX/a/important.log"
echo "keep me" > "$SANDBOX/b/c/config.yaml"
echo "keep me" > "$SANDBOX/d/readme.txt"
