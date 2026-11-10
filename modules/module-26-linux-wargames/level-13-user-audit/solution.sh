#!/bin/bash
: > audit.txt
for f in departed/*.pub; do
  u=$(basename "$f" .pub)
  sysroot/bin/usermod -L "$u"
  echo "locked $u" >> audit.txt
done
awk -F: '$3 == 0 && $1 != "root" { print $1 }' sysroot/etc/passwd | while read -r b; do
  sysroot/bin/userdel "$b"
  echo "uid0 $b" >> audit.txt
done
for f in departed/*.pub; do
  u=$(basename "$f" .pub); body=$(awk '{ print $2 }' "$f")
  for ak in $(find sysroot -name authorized_keys); do
    if grep -qF "$body" "$ak"; then
      echo "key ${ak#sysroot/} $u" >> audit.txt
      grep -vF "$body" "$ak" > "$ak.new"; mv "$ak.new" "$ak"
    fi
  done
done
sort -o audit.txt audit.txt
cat audit.txt
