#!/bin/bash
# Six monthly .tar.xz archives grouped by the date in the file name; archived
# logs removed; November untouched.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
SUMS=.lm-state/logs.sums
if [ ! -s "$SUMS" ]; then
  echo "❌ the level's reference data in .lm-state/ is gone; type 'reset'"
  exit 1
fi
MONTHS="2026-05 2026-06 2026-07 2026-08 2026-09 2026-10"

# November: still plain and unchanged.
while read -r name sum size; do
  case "$name" in app-2026-11-*) ;; *) continue ;; esac
  if [ ! -f "logs/$name" ]; then
    echo "❌ logs/$name is gone; the current month stays plain in logs/ (type 'reset')"
    exit 1
  fi
  if [ "$(cksum < "logs/$name")" != "$sum $size" ]; then
    echo "❌ logs/$name was changed; the current month must stay as it is"
    exit 1
  fi
done < "$SUMS"

if [ ! -d archive ]; then
  echo "❌ archive/ does not exist yet"
  exit 1
fi
extra=$(cd archive && ls -A | grep -vxE '2026-(05|06|07|08|09|10)\.tar\.xz' | head -1)
if [ -n "$extra" ]; then
  echo "❌ archive/$extra should not be there; archive/ holds only 2026-05.tar.xz ... 2026-10.tar.xz"
  exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for m in $MONTHS; do
  a="archive/$m.tar.xz"
  if [ ! -f "$a" ]; then
    echo "❌ $a does not exist yet"
    exit 1
  fi
  if [ "$(head -c 6 "$a" | od -An -tx1 | tr -d ' \n')" != "fd377a585a00" ]; then
    echo "❌ $a is not xz-compressed (check it with: file $a)"
    exit 1
  fi
  if ! xz -t "$a" 2>/dev/null; then
    echo "❌ $a is damaged (xz -t fails)"
    exit 1
  fi
  rm -rf "${tmp:?}"/*
  if ! xz -dc "$a" | tar -xf - -C "$tmp" 2>/dev/null; then
    echo "❌ $a does not contain a tar archive"
    exit 1
  fi
  got=$(cd "$tmp" && find . -type f | sed 's|.*/||' | LC_ALL=C sort)
  want=$(awk -v m="$m" 'index($1, "app-" m "-") == 1 {print $1}' "$SUMS" | LC_ALL=C sort)
  if [ "$got" != "$want" ]; then
    wrong=$(comm -13 <(printf '%s\n' "$want") <(printf '%s\n' "$got") | head -1)
    missing=$(comm -23 <(printf '%s\n' "$want") <(printf '%s\n' "$got") | head -1)
    if [ -n "$wrong" ]; then
      echo "❌ $a holds $wrong, which does not belong to $m (group by the date in the file name; ls -l shows when a file was last written, not which day it covers)"
    else
      echo "❌ $a is missing $missing (pick each month's logs by the date in the file name)"
    fi
    exit 1
  fi
  dup=$(cd "$tmp" && find . -type f | sed 's|.*/||' | sort | uniq -d | head -1)
  if [ -n "$dup" ]; then
    echo "❌ $a holds $dup more than once"
    exit 1
  fi
  while read -r name sum size; do
    p=$(cd "$tmp" && find . -type f -name "$name" | head -1)
    if [ "$(cksum < "$tmp/$p")" != "$sum $size" ]; then
      echo "❌ $name inside $a differs from the original log"
      exit 1
    fi
  done < <(awk -v m="$m" 'index($1, "app-" m "-") == 1' "$SUMS")
done

left=$(cd logs && ls -A | grep -v '^app-2026-11-' | head -1)
if [ -n "$left" ]; then
  n=$(cd logs && ls -A | grep -vc '^app-2026-11-')
  echo "❌ the archives are fine, but logs/ still holds $n file(s) from before November, e.g. $left; remove the archived logs"
  exit 1
fi
echo "✅ six monthly .tar.xz archives verified, only November is left in logs/"
exit 0
