#!/bin/bash
# The archive must be gzip, unpack into exactly one site/ directory, and hold
# every file of build/dist/site/ (hidden ones too) with the same content.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
ARCHIVE=release-2.3.tar.gz
FILES="site/.htaccess site/.well-known/security.txt site/about/index.html site/css/site.css site/img/logo.svg site/index.html site/js/app.js site/robots.txt"

for f in $FILES; do
  if [ ! -f "build/dist/$f" ]; then
    echo "❌ build/dist/$f is missing; leave build/ as it is (type 'reset' to get it back)"
    exit 1
  fi
done
inside=$(find build -name "$ARCHIVE" | head -1)
if [ -n "$inside" ]; then
  echo "❌ there is a $ARCHIVE inside build/ ($inside); an archive made inside the folder ends up in the next release. Remove it and create the archive in the sandbox root"
  exit 1
fi
if [ ! -f "$ARCHIVE" ]; then
  echo "❌ $ARCHIVE does not exist in the sandbox root yet"
  exit 1
fi
if [ "$(head -c 2 "$ARCHIVE" | od -An -tx1 | tr -d ' \n')" != "1f8b" ]; then
  echo "❌ $ARCHIVE is not gzip-compressed (check it with: file $ARCHIVE)"
  exit 1
fi
if ! members=$(tar -tzf "$ARCHIVE" 2>/dev/null); then
  echo "❌ tar cannot read $ARCHIVE; create it again"
  exit 1
fi
members=$(printf '%s\n' "$members" | sed -e 's|^\./||' -e 's|/$||' | grep -v '^\.\{0,1\}$')

if printf '%s\n' "$members" | grep -q '^build/'; then
  echo "❌ members are stored as build/dist/site/...; unpacking would create build/dist/site/, not site/ (tar can change into build/dist first)"
  exit 1
fi
if printf '%s\n' "$members" | grep -q "$ARCHIVE"; then
  echo "❌ $ARCHIVE contains a copy of itself"
  exit 1
fi
outside=$(printf '%s\n' "$members" | grep -v -e '^site$' -e '^site/' | head -1)
if [ -n "$outside" ]; then
  echo "❌ '$outside' is not inside site/; unpacking would drop it straight into the current directory (pack the folder site, not its contents)"
  exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
tar -xzf "$ARCHIVE" -C "$tmp" 2>/dev/null
got=$(cd "$tmp" && find site -type f | LC_ALL=C sort | tr '\n' ' ')
want=$(printf '%s\n' $FILES | LC_ALL=C sort | tr '\n' ' ')
if [ "$got" != "$want" ]; then
  for f in $FILES; do
    if [ ! -f "$tmp/$f" ]; then
      echo "❌ $f is not in the archive (a glob like site/* skips hidden files)"
      exit 1
    fi
  done
  extra=$(cd "$tmp" && find site -type f | grep -vxF -f <(printf '%s\n' $FILES) | head -1)
  echo "❌ the archive holds $extra, which is not part of build/dist/site/"
  exit 1
fi
for f in $FILES; do
  if ! cmp -s "$tmp/$f" "build/dist/$f"; then
    echo "❌ $f in the archive differs from build/dist/$f"
    exit 1
  fi
done
echo "✅ $ARCHIVE unpacks into site/ with all $(echo $FILES | wc -w | tr -d ' ') files, .htaccess included"
exit 0
