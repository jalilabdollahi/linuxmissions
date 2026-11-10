#!/bin/bash
# app/ was restored from the old web host, where it lived at a different
# absolute path (OLD, picked at random). Its links are absolute: the internal ones
# point into OLD (dangling here), the external ones point at system paths, one of
# them at a sibling directory whose name merely starts like OLD. One internal link
# is a chain through the "current" directory link, and one link name has a space.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state
pick() { local a=("$@"); echo "${a[RANDOM % ${#a[@]}]}"; }
OLD=$(pick /srv/shop /srv/webstore /opt/storefront /var/www/shop)
REL=$((2 + RANDOM % 6))

mkdir -p "app/releases/r$((REL - 1))/conf" "app/releases/r$REL/bin" "app/releases/r$REL/conf" \
         "app/releases/r$REL/lib" app/shared/uploads app/etc app/bin
echo "version=$((REL - 1))" > "app/releases/r$((REL - 1))/conf/app.conf"
echo "version=$REL" > "app/releases/r$REL/conf/app.conf"
printf '#!/bin/sh\necho "shop %s starting"\n' "$REL" > "app/releases/r$REL/bin/run"
chmod 755 "app/releases/r$REL/bin/run"
echo "release $REL notes: $RANDOM" > "app/releases/r$REL/NOTES.txt"
echo "lib-$RANDOM" > "app/releases/r$REL/lib/libshop.so.1"
echo "upload-$RANDOM" > app/shared/uploads/logo.png
echo "secret=$RANDOM" > app/etc/settings.ini

# internal links, all absolute and pointing into OLD
ln -s "$OLD/releases/r$REL" app/current
ln -s "$OLD/current/conf/app.conf" app/etc/app.conf          # through the "current" link
ln -s "$OLD/current/bin/run" app/bin/shop
ln -s "$OLD/shared/uploads" app/releases/r$REL/uploads
ln -s "$OLD/etc/settings.ini" "app/releases/r$REL/conf/settings.ini"
ln -s "$OLD/releases/r$REL/lib/libshop.so.1" "app/releases/r$REL/lib/libshop.so"
ln -s "$OLD/releases/r$REL/NOTES.txt" "app/latest release notes"
# external links: must stay exactly as they are
ln -s /usr/share/zoneinfo/UTC app/etc/localtime
ln -s /var/log/shop app/logs
ln -s "${OLD}-data/exports" app/exports

# where each internal link must end up (real file or directory, relative to app/)
printf '%s\n' \
  "current|releases/r$REL" \
  "etc/app.conf|releases/r$REL/conf/app.conf" \
  "bin/shop|releases/r$REL/bin/run" \
  "releases/r$REL/uploads|shared/uploads" \
  "releases/r$REL/conf/settings.ini|etc/settings.ini" \
  "releases/r$REL/lib/libshop.so|releases/r$REL/lib/libshop.so.1" \
  "latest release notes|releases/r$REL/NOTES.txt" > .lm-state/expect
printf '%s\n' etc/localtime logs exports | while read -r l; do
  printf '%s|%s\n' "$l" "$(readlink "app/$l")"
done > .lm-state/external
( cd app && find . -type f -printf '%p %s\n' | LC_ALL=C sort | sha256sum | cut -d' ' -f1 ) > .lm-state/files
( cd app && find . -type l -printf '%p\n' | LC_ALL=C sort ) > .lm-state/links

cat > RESTORE-NOTES.txt <<EOT
The box that ran the shop died. We restored its backup to ./app, but the tree
used to live somewhere else and was never meant to move. Every internal symlink
is an absolute path to the old home, so nothing resolves here, and it will break
again the next time the tree is moved.

Make every link that points inside the old tree a relative link that still
leads to the same file or directory. Links that point at other places on the
system (time zone, logs, the exports directory of a neighbouring service) are
not ours to change.
EOT
