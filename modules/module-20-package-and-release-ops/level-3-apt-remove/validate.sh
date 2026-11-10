#!/bin/bash
# oldmon must be gone from the dpkg database (not merely rc), its conffiles
# deleted, and every other package (state and version) unchanged.
SANDBOX="$1"
ROOT="$SANDBOX/rootfs"
Q=(/usr/bin/dpkg-query --root="$ROOT")

ST="$("${Q[@]}" -W -f='${db:Status-Abbrev}' oldmon 2>/dev/null | tr -d ' ')"
case "$ST" in
  ii|hi) echo "❌ oldmon is still installed"; exit 1 ;;
  rc)    echo "❌ oldmon is only removed (state rc): its configuration files and database entry are still there"; exit 1 ;;
  "")    ;;
  *)     echo "❌ oldmon is still in the package database (state $ST)"; exit 1 ;;
esac
for f in etc/oldmon/oldmon.conf etc/oldmon/rules.d/default.rules; do
  if [ -e "$ROOT/$f" ]; then
    echo "❌ $f is still on disk"
    exit 1
  fi
done
if ls "$ROOT"/etc/oldmon/oldmon.conf* >/dev/null 2>&1; then
  echo "❌ a leftover copy of oldmon.conf is still in etc/oldmon/"
  exit 1
fi
NOW="$("${Q[@]}" -W -f='${db:Status-Abbrev}${Package} ${Version}\n' | grep -v -e ' base-files ' -e 'oldmon ' | sort)"
if [ "$NOW" != "$(cat "$SANDBOX/.lm/baseline")" ]; then
  CH="$(diff "$SANDBOX/.lm/baseline" <(echo "$NOW") | grep '^[<>]' | head -1)"
  echo "❌ another package changed ($CH): only oldmon should go"
  exit 1
fi
if [ ! -f "$ROOT/etc/oldmon/plugins.d/disk.conf" ] || [ ! -f "$ROOT/etc/legacy-ntp/ntp.conf" ]; then
  echo "❌ a config file that belongs to another package was deleted"
  exit 1
fi
echo "✅ oldmon is gone for good, and its neighbours were left alone"
