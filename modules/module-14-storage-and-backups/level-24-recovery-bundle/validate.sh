#!/bin/bash
# Join parts -> outer sums -> extract -> inner manifest -> contents vs box/ -> sfdisk replay.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
LIMIT=20000000
shopt -s nullglob
parts=(out/dr-bundle.tgz.part-*)
[ "${#parts[@]}" -gt 0 ] || { echo "❌ out/ has no parts named dr-bundle.tgz.part-aa, -ab ... yet"; exit 1; }
[ -f out/SHA256SUMS ] || { echo "❌ out/SHA256SUMS is missing"; exit 1; }
others=$(ls -A out | grep -v '^dr-bundle\.tgz\.part-' | grep -vx 'SHA256SUMS')
[ -z "$others" ] || { echo "❌ out/ must contain only the parts and SHA256SUMS (found: $(echo $others | cut -c1-60))"; exit 1; }
for p in "${parts[@]}"; do
  s=$(stat -c %s "$p")
  [ "$s" -gt 0 ] || { echo "❌ $p is empty"; exit 1; }
  if [ "$s" -gt "$LIMIT" ]; then
    echo "❌ $p is $s bytes, over the $LIMIT-byte limit (split's suffix M means 1048576-byte units, MB means 1000000)"
    exit 1
  fi
done
if [ "${#parts[@]}" -lt 2 ]; then echo "❌ only one part: the content is bigger than a single 20,000,000-byte part, something is missing"; exit 1; fi

if ! ( cd out && sha256sum -c --quiet SHA256SUMS >/dev/null 2>&1 ); then
  echo "❌ 'cd out && sha256sum -c SHA256SUMS' fails: the sums do not match the parts (or list other file names or paths)"
  exit 1
fi
listed=$(awk '{print $2}' out/SHA256SUMS | LC_ALL=C sort)
have=$(printf '%s\n' "${parts[@]}" | sed 's#^out/##' | LC_ALL=C sort)
[ "$listed" = "$have" ] || { echo "❌ SHA256SUMS must list every part, and only the parts"; exit 1; }

W=$(mktemp -d "$SANDBOX/.lm-state/val.XXXXXX") || exit 1
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/x"
if ! cat "${parts[@]}" | tar -xzf - -C "$W/x" 2>"$W/err"; then
  echo "❌ the parts do not join into a valid gzip tar archive ($(head -c 100 "$W/err"))"
  exit 1
fi
d="$W/x/dr-bundle"
[ -d "$d" ] || { echo "❌ the archive must contain one top-level directory named dr-bundle"; exit 1; }
[ "$(ls -A "$W/x")" = dr-bundle ] || { echo "❌ the archive has other top-level entries besides dr-bundle"; exit 1; }
if [ -n "$(find "$d" -type l | head -1)" ]; then
  echo "❌ the bundle contains a symbolic link ($(cd "$d" && find . -type l | head -1)): ship the file it points to under that name"
  exit 1
fi
for f in fstab disk.sfdisk MANIFEST.sha256; do [ -f "$d/$f" ] || { echo "❌ dr-bundle/$f is missing"; exit 1; }; done

# inner manifest
if ! ( cd "$d" && sha256sum -c --quiet MANIFEST.sha256 >/dev/null 2>&1 ); then
  echo "❌ after extraction 'cd dr-bundle && sha256sum -c MANIFEST.sha256' fails: the manifest paths must be relative to dr-bundle (no stage-directory prefix) and the sums right"
  exit 1
fi
want_files=$( cd "$d" && find . -type f ! -name MANIFEST.sha256 | sed 's#^\./##' | LC_ALL=C sort )
in_manifest=$( sed -E 's/^[0-9a-f]{64}[ ][ *]//; s#^\./##' "$d/MANIFEST.sha256" | LC_ALL=C sort )
if [ "$want_files" != "$in_manifest" ]; then
  m=$(comm -23 <(printf '%s\n' "$want_files") <(printf '%s\n' "$in_manifest") | head -1)
  if [ -n "$m" ]; then echo "❌ MANIFEST.sha256 does not cover $m"; else echo "❌ MANIFEST.sha256 lists a file that is not in the bundle (or lists itself)"; fi
  exit 1
fi

# contents versus the server tree
while IFS= read -r p; do
  [ -n "$p" ] || continue
  src="box/$p"; dst="$d/files/$p"
  if [ ! -e "$dst" ]; then echo "❌ dr-bundle/files/$p is missing"; exit 1; fi
  if ! cmp -s "$src" "$dst"; then echo "❌ dr-bundle/files/$p does not have the content of $p (a link target must be shipped, not the link text)"; exit 1; fi
done < bundle.list
listed=$(LC_ALL=C sort bundle.list)
inb=$(cd "$d/files" 2>/dev/null && find . -type f | sed 's#^\./##' | LC_ALL=C sort)
if [ "$listed" != "$inb" ]; then
  x=$(comm -13 <(printf '%s\n' "$listed") <(printf '%s\n' "$inb") | head -1)
  echo "❌ dr-bundle/files contains $x, which is not in bundle.list"; exit 1
fi
cmp -s box/etc/fstab "$d/fstab" || { echo "❌ dr-bundle/fstab is not a copy of box/etc/fstab"; exit 1; }
if [ "$(ls -A "$d" | LC_ALL=C sort | tr '\n' ' ')" != "MANIFEST.sha256 disk.sfdisk files fstab " ]; then
  echo "❌ dr-bundle must contain exactly files/, fstab, disk.sfdisk and MANIFEST.sha256"; exit 1
fi

# replay the partition table on a blank image of the same size
truncate -s "$(cat .lm-state/disk-size)" "$W/blank.img"
if ! sfdisk -q "$W/blank.img" < "$d/disk.sfdisk" >/dev/null 2>"$W/err"; then
  echo "❌ disk.sfdisk cannot be applied with sfdisk to a blank image ($(head -c 120 "$W/err")): is it the dump made with the -d option?"
  exit 1
fi
if [ "$(sfdisk -d "$W/blank.img" | sed -E '/^device:/d; s#^[^ ]+([0-9]+) : #p\1 : #')" != "$(cat .lm-state/table.norm)" ]; then
  echo "❌ replaying disk.sfdisk on a blank image gives a different partition table than disk.img has"
  exit 1
fi
echo "✅ ${#parts[@]} parts under 20,000,000 bytes join, verify, extract and match the server; the partition table replays identically"
