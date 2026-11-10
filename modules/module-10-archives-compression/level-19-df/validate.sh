#!/bin/bash
# $1 = sandbox path
# Recomputes the needs from restore.tar.xz and reads every host snapshot the
# way df works: /srv lives on the mount "/srv" if there is one, otherwise on "/".
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -f restore.tar.xz ] || ! xz -t restore.tar.xz 2>/dev/null; then
  echo "❌ restore.tar.xz is missing or damaged; type 'reset'"
  exit 1
fi
if [ "$(ls hosts/*.txt 2>/dev/null | wc -l | tr -d ' ')" -ne 6 ]; then
  echo "❌ hosts/ should hold the 6 snapshots; type 'reset'"
  exit 1
fi
need_kib=$(( ( $(xz -dc restore.tar.xz | wc -c) + 1023 ) / 1024 ))
need_ino=$(xz -dc restore.tar.xz | tar -tf - | wc -l | tr -d ' ')

expected=$(for h in hosts/*.txt; do
  awk -v k="$need_kib" -v n="$need_ino" -v host="$(basename "$h" .txt)" '
    /^\$ df -PT/ { s = "kib"; next }
    /^\$ df -i/  { s = "ino"; next }
    s == "kib" && ($NF == "/srv" || $NF == "/") { free["kib", $NF] = $5 }
    s == "ino" && ($NF == "/srv" || $NF == "/") { free["ino", $NF] = $4 }
    END {
      m = (("kib", "/srv") in free) ? "/srv" : "/"
      if (free["kib", m] + 0 >= k && free["ino", m] + 0 >= n) print host
    }' "$h"
done | LC_ALL=C sort)

if [ ! -f targets.txt ]; then
  echo "❌ targets.txt does not exist yet"
  exit 1
fi
got=$(tr -d '\r' < targets.txt | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/\.txt$//' | grep -v '^$' | LC_ALL=C sort -u)
if [ "$got" = "$expected" ]; then
  echo "✅ targets.txt names the $(printf '%s\n' "$expected" | grep -c .) kiosks that can take the restore (needs $need_kib KiB and $need_ino inodes)"
  exit 0
fi

for h in $got; do
  if [ ! -f "hosts/$h.txt" ]; then
    echo "❌ targets.txt lists '$h', which is not one of the hosts (use the names of the files in hosts/ without .txt)"
    exit 1
  fi
done
wrong=$(printf '%s\n' "$got" | grep -vxF -e "$expected" | head -1)
if [ -n "$wrong" ]; then
  echo "❌ targets.txt lists $wrong, but it can't take the restore (check space AND inodes, on the filesystem /srv really lives on)"
  exit 1
fi
missing=$(printf '%s\n' "$expected" | grep -vxF -e "$got" | grep -c .)
echo "❌ targets.txt misses $missing kiosk(s) that can take the restore"
exit 1
