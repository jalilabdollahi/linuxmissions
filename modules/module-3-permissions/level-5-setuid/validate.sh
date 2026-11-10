#!/bin/bash
SANDBOX="$1"
OUT="$SANDBOX/suid_files.txt"

if [ ! -f "$OUT" ]; then
  echo "❌ suid_files.txt not found"
  exit 1
fi

expected=$(printf '%s\n' \
  "bin/group_tool" \
  "bin/special_tool" \
  "lib/libcrypt.so.1" \
  "opt/backup/run backup" \
  "sbin/.dbus-helper" | sort)

# Normalize: strip trailing spaces, and the ./ or $SANDBOX/ prefix
got=$(sed -e 's/[[:space:]]*$//' -e '/^$/d' \
          -e "s|^$SANDBOX/||" -e 's|^\./||' "$OUT" | sort -u)

missing=$(comm -23 <(printf '%s\n' "$expected") <(printf '%s\n' "$got") | grep -c .)
extra=$(comm -13 <(printf '%s\n' "$expected") <(printf '%s\n' "$got") | grep -c .)

if [ "$missing" -gt 0 ] && [ "$extra" -gt 0 ]; then
  echo "❌ suid_files.txt misses $missing SUID/SGID file(s) and lists $extra path(s) that shouldn't be there"
  exit 1
elif [ "$missing" -gt 0 ]; then
  echo "❌ suid_files.txt misses $missing SUID/SGID file(s) (hidden files and odd names count too)"
  exit 1
elif [ "$extra" -gt 0 ]; then
  echo "❌ suid_files.txt lists $extra path(s) that are not SUID/SGID regular files"
  exit 1
fi
echo "✅ All 5 planted SUID/SGID files found, and nothing else"
exit 0
