#!/bin/bash
# backups/ must hold exactly one directory named config-<today>-<version>
# whose content equals config/. The version is VERSION without its CR LF.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -f VERSION ] || [ ! -f config/gateway.yaml ]; then
  echo "❌ VERSION or config/ is missing; type reset to start over"
  exit 1
fi
version="$(tr -d '\r\n' < VERSION)"
today="$(date +%Y%m%d)"
want="config-$today-$version"

n="$(ls -A backups 2>/dev/null | wc -l | tr -d ' ')"
if [ "$n" -eq 0 ]; then
  echo "❌ backups/ is still empty"
  exit 1
fi
if [ "$n" -gt 1 ]; then
  echo "❌ backups/ holds $n entries; keep only the one correct snapshot (remove the others)"
  exit 1
fi

for entry in backups/* backups/.*; do
  case "$entry" in backups/.|backups/..) continue ;; esac
  [ -e "$entry" ] || [ -L "$entry" ] || continue
  name="${entry#backups/}"
done

cr="$(printf '\r')"
case "$name" in
  *"$cr"*) echo "❌ the snapshot name contains an invisible carriage return (\\r): VERSION has Windows line endings, and \$(...) only strips trailing newlines (try: ls backups | cat -v)"; exit 1 ;;
esac
if [ "$name" != "$want" ]; then
  case "$name" in
    "config-$(date +%Y-%m-%d)-"*) echo "❌ the date in '$name' has dashes; the policy wants YYYYMMDD" ;;
    "config-$today-"*) echo "❌ '$name' has the right date, but the version part doesn't match the VERSION file" ;;
    *"-$version") echo "❌ '$name' has the right version, but not today's date as YYYYMMDD" ;;
    *) echo "❌ the snapshot is called '$name'; expected config-<YYYYMMDD>-<version from VERSION>" ;;
  esac
  exit 1
fi
if [ ! -d "backups/$name" ]; then
  echo "❌ backups/$name is not a directory"
  exit 1
fi
if [ -d "backups/$name/config" ] && diff -r config "backups/$name/config" >/dev/null 2>&1; then
  echo "❌ the files ended up one level too deep, in backups/$name/config/ (cp -r into an existing directory copies the directory itself)"
  exit 1
fi
if ! diff -r config "backups/$name" >/dev/null 2>&1; then
  echo "❌ backups/$name does not hold the same files as config/ (subdirectories and hidden files included)"
  exit 1
fi

echo "✅ backups/$want is an exact copy of config/"
exit 0
