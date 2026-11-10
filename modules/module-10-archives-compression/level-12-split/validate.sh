#!/bin/bash
# Every part <= 5,000,000 bytes, parts join (in glob order) to the original,
# and db-backup.sha256 verifies the rebuilt file in a fresh folder.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
CAP=5000000
if [ ! -s .lm-state/backup.sum ]; then
  echo "❌ the level's reference data in .lm-state/ is gone; type 'reset'"
  exit 1
fi
if [ ! -f db-backup.tar.gz ]; then
  echo "❌ db-backup.tar.gz is gone; keep the original (type 'reset')"
  exit 1
fi
if [ "$(cksum < db-backup.tar.gz)" != "$(cat .lm-state/backup.sum)" ]; then
  echo "❌ db-backup.tar.gz was changed; type 'reset'"
  exit 1
fi
if [ ! -d outgoing ]; then
  echo "❌ outgoing/ does not exist"
  exit 1
fi

extra=$(cd outgoing && ls -A | grep -v -e '^db-backup\.tar\.gz\.part-[a-z0-9]\{1,\}$' -e '^db-backup\.sha256$' | head -1)
if [ -n "$extra" ]; then
  echo "❌ outgoing/$extra does not belong in the upload; only db-backup.tar.gz.part-* and db-backup.sha256"
  exit 1
fi
parts=$(cd outgoing && ls | grep '^db-backup\.tar\.gz\.part-' | LC_ALL=C sort)
if [ -z "$parts" ]; then
  echo "❌ outgoing/ has no db-backup.tar.gz.part-* pieces yet"
  exit 1
fi
for p in $parts; do
  s=$(wc -c < "outgoing/$p" | tr -d ' ')
  if [ "$s" -gt "$CAP" ]; then
    if [ "$s" -eq 5242880 ]; then
      echo "❌ outgoing/$p is 5,242,880 bytes: that is 5 MiB (what split means by 5M), and the share's limit is 5,000,000 bytes"
    else
      echo "❌ outgoing/$p is $s bytes, over the share's limit of 5,000,000 bytes"
    fi
    exit 1
  fi
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for p in $parts; do cat "outgoing/$p"; done > "$tmp/db-backup.tar.gz"
if ! cmp -s "$tmp/db-backup.tar.gz" db-backup.tar.gz; then
  echo "❌ the parts joined in name order do not give back db-backup.tar.gz (a piece is missing, extra, or out of order)"
  exit 1
fi

if [ ! -f outgoing/db-backup.sha256 ]; then
  echo "❌ the parts are good; outgoing/db-backup.sha256 is still missing"
  exit 1
fi
line=$(grep -E '[[:space:]][*]?(\./)?db-backup\.tar\.gz$' outgoing/db-backup.sha256 | head -1)
if [ -z "$line" ]; then
  if grep -q 'db-backup\.tar\.gz$' outgoing/db-backup.sha256; then
    echo "❌ db-backup.sha256 names the backup with a directory ($(grep -o '[^ *]*db-backup\.tar\.gz$' outgoing/db-backup.sha256 | head -1)); the vendor rebuilds it in their own folder, so use the plain file name"
  else
    echo "❌ db-backup.sha256 has no line for db-backup.tar.gz; the vendor checks the rebuilt file"
  fi
  exit 1
fi
cp outgoing/db-backup.sha256 "$tmp/"
if command -v sha256sum >/dev/null 2>&1; then check="sha256sum -c"; else check="shasum -a 256 -c"; fi
if ! (cd "$tmp" && $check db-backup.sha256 >/dev/null 2>&1); then
  echo "❌ sha256sum -c db-backup.sha256 fails in the vendor's folder; the checksum does not match the rebuilt file"
  exit 1
fi
n=$(printf '%s\n' $parts | wc -l | tr -d ' ')
echo "✅ $n parts, all within 5,000,000 bytes, rebuild the backup and the checksum verifies"
exit 0
