#!/bin/bash
# Bind mount = a block-device mount whose mountinfo root field is not "/".
# Its source dir is the mount point of the same device's root="/" mount + root.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if ! cksum mountinfo.txt mounts.txt 2>/dev/null | cmp -s - .lm-state/inputs; then
  echo "❌ mountinfo.txt or mounts.txt was changed; type 'reset' to get the captures back"
  exit 1
fi
for f in binds.txt backup-excludes.txt; do
  [ -f "$f" ] || { echo "❌ $f does not exist yet"; exit 1; }
done

WANT=$(awk '
  { for (i = 7; $i != "-"; i++); fs = $(i + 1)
    if (fs !~ /^(ext[234]|xfs)$/) next
    if ($4 == "/") main[$3] = $5; else { n++; bmp[n] = $5; bdev[n] = $3; broot[n] = $4 } }
  END { for (k = 1; k <= n; k++) { m = main[bdev[k]]; if (m == "/") m = ""; print bmp[k], m broot[k] } }
' mountinfo.txt | LC_ALL=C sort)
ORDINARY=$(awk '{ for (i = 7; $i != "-"; i++); if ($4 == "/") print $5 }' mountinfo.txt)

GOT=$(tr -d '\r' < binds.txt | awk 'NF { $1 = $1; print }' | LC_ALL=C sort)
if [ -z "$GOT" ]; then echo "❌ binds.txt is empty"; exit 1; fi

while IFS= read -r row; do
  set -- $row
  if [ $# -ne 2 ] || [ "${1:0:1}" != / ] || [ "${2:0:1}" != / ]; then
    echo "❌ binds.txt line '$row' is not 'MOUNTPOINT SOURCE_DIR' with two absolute paths"
    exit 1
  fi
  if printf '%s\n' "$ORDINARY" | grep -qxF -- "$1"; then
    echo "❌ $1 is an ordinary mount (its mountinfo root field is /), not a bind mount"
    exit 1
  fi
  w=$(printf '%s\n' "$WANT" | awk -v m="$1" '$1 == m { print $2 }')
  if [ -z "$w" ]; then
    echo "❌ $1 is not a mount point in mountinfo.txt"
    exit 1
  fi
  if [ "$w" != "$2" ]; then
    echo "❌ the source for $1 is wrong: build it from the root field plus the place its device is normally mounted (the root field alone is a path inside its disk, not on the running system)"
    exit 1
  fi
done <<< "$GOT"
if [ "$(printf '%s\n' "$GOT" | cut -d' ' -f1 | uniq -d | wc -l)" -ne 0 ]; then
  echo "❌ a mount point appears twice in binds.txt"
  exit 1
fi
have=$(printf '%s\n' "$GOT" | wc -l); need=$(printf '%s\n' "$WANT" | wc -l)
if [ "$have" -lt "$need" ]; then
  echo "❌ binds.txt has $have of the $need bind mounts; one of them hides in the data disk or at a deeper path"
  exit 1
fi
if [ "$GOT" != "$WANT" ]; then echo "❌ binds.txt does not match the mountinfo capture"; exit 1; fi

EXC=$(tr -d '\r' < backup-excludes.txt | sed 's/[[:space:]]*$//' | awk 'NF')
ln=0
while IFS= read -r p; do
  ln=$((ln + 1))
  case "$p" in
    /*/) ;;
    *) echo "❌ backup-excludes.txt line $ln ('$p') is not an anchored directory pattern: start with / and end with /"; exit 1 ;;
  esac
  src=$(printf '%s\n' "$WANT" | awk -v p="$p" '{ if ($2 "/" == p) { print "y"; exit } }')
  if [ -n "$src" ]; then
    echo "❌ $p is the original directory; excluding it would drop the uploads from the backup entirely"
    exit 1
  fi
  if ! printf '%s\n' "$WANT" | awk -v p="$p" '{ if ($1 "/" == p) f = 1 } END { exit !f }'; then
    echo "❌ $p is not the mount point of a bind mount"
    exit 1
  fi
done <<< "$EXC"
WANTX=$(printf '%s\n' "$WANT" | awk '{ print $1 "/" }' | LC_ALL=C sort)
if [ "$(printf '%s\n' "$EXC" | LC_ALL=C sort -u)" != "$WANTX" ]; then
  echo "❌ backup-excludes.txt is missing some of the bind mount points"
  exit 1
fi
echo "✅ $need bind mounts found, and the backup now skips the aliases and keeps the originals"
exit 0
