#!/bin/bash
# restore/ must hold etc/nginx exactly as in the backup, and nothing else.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -f etc-backup.tar.gz ] || ! tar -tzf etc-backup.tar.gz ./etc/nginx/nginx.conf >/dev/null 2>&1; then
  echo "❌ etc-backup.tar.gz is missing or damaged; type 'reset' to get it back"
  exit 1
fi
if [ ! -d restore/etc/nginx ]; then
  if [ -e restore/nginx ]; then
    echo "❌ restore/nginx exists, but the backup's path is etc/nginx; extract with the stored path so it lands in restore/etc/nginx"
  else
    echo "❌ restore/etc/nginx does not exist yet"
  fi
  exit 1
fi

other=$(cd restore && find . -mindepth 1 ! -path ./etc ! -path './etc/nginx' ! -path './etc/nginx/*' | sed 's|^\./||' | head -1)
if [ -n "$other" ]; then
  n=$(cd restore && find . -mindepth 1 ! -path ./etc ! -path './etc/nginx' ! -path './etc/nginx/*' | wc -l | tr -d ' ')
  echo "❌ restore/ holds $n path(s) that are not part of etc/nginx, e.g. restore/$other; only nginx was wanted"
  exit 1
fi

ref=$(mktemp -d)
trap 'rm -rf "$ref"' EXIT
tar -xzf etc-backup.tar.gz -C "$ref" ./etc/nginx 2>/dev/null

want=$(cd "$ref/etc/nginx" && find . | LC_ALL=C sort)
got=$(cd restore/etc/nginx && find . | LC_ALL=C sort)
if [ "$want" != "$got" ]; then
  missing=$(comm -23 <(printf '%s\n' "$want") <(printf '%s\n' "$got") | head -1)
  if [ -n "$missing" ]; then
    echo "❌ restore/etc/nginx/${missing#./} is missing; the whole nginx directory from the backup is needed"
  else
    extra=$(comm -13 <(printf '%s\n' "$want") <(printf '%s\n' "$got") | head -1)
    echo "❌ restore/etc/nginx/${extra#./} is not in the backup's nginx directory"
  fi
  exit 1
fi
while IFS= read -r p; do
  r="$ref/etc/nginx/$p"; g="restore/etc/nginx/$p"
  if [ -L "$r" ]; then
    if [ ! -L "$g" ] || [ "$(readlink "$r")" != "$(readlink "$g")" ]; then
      echo "❌ restore/etc/nginx/${p#./} should be a symlink to $(readlink "$r"), as in the backup"
      exit 1
    fi
  elif [ -f "$r" ] && ! cmp -s "$r" "$g"; then
    echo "❌ restore/etc/nginx/${p#./} differs from the copy in the backup"
    exit 1
  fi
done <<< "$want"

n=$(cd restore/etc/nginx && find . -type f | wc -l | tr -d ' ')
echo "✅ restore/etc/nginx matches the backup ($n files and the sites-enabled links), nothing else was unpacked"
exit 0
