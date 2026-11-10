#!/bin/bash
for a in backups/*.tar offsite/*.bak; do
  printf '%s ' "$a"; tar -tf "$a" >/dev/null 2>&1 && echo ok || echo DAMAGED
done
ls -l --time-style=long-iso backups offsite
mkdir -p restored
good=$(ls offsite/*.bak | while read -r f; do [ "$(stat -c %y "$f" | cut -c1-16)" = "2026-11-10 18:02" ] && echo "$f"; done)
for a in backups/share-full-2026-11-08.tar backups/share-inc-2026-11-09.tar "$good"; do
  tar -x --listed-incremental=/dev/null -f "$a" -C restored
done
