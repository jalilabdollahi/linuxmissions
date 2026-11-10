#!/bin/bash
pid=$(cat .lm-state/pid)
held=$(lsof -p "$pid" -Fn | sed -n 's/^n//p' | grep "^$PWD/var/")
is_held() { grep -qxF "$(realpath "$1")" <<<"$held"; }
find var -name '*.log' -mtime +7 -print0 | while IFS= read -r -d '' f; do is_held "$f" || rm -- "$f"; done
find var -name '*.log' -mtime +1 -print0 | while IFS= read -r -d '' f; do is_held "$f" || gzip -- "$f"; done
find var/crash -name 'core.*' -mtime +30 -delete
