#!/bin/bash
# sysroot/etc/hosts: exactly one 127.0.1.1 line whose first name is the server's
# hostname, all other lines unchanged. Rescue etc/hosts untouched.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
H=sysroot/etc/hosts

if ! cksum etc/hosts etc/hostname sysroot/etc/hostname 2>/dev/null | cmp -s - .lm-state/sums; then
  if ! cksum etc/hosts 2>/dev/null | cmp -s - <(head -1 .lm-state/sums); then
    echo "❌ the rescue system's own etc/hosts was changed: the broken server's file is under sysroot/"
  else
    echo "❌ a hostname file was changed; the hostnames are the facts, only the hosts file is wrong"
  fi
  exit 1
fi
[ -f "$H" ] || { echo "❌ sysroot/etc/hosts is gone"; exit 1; }

HOST=$(tr -d '\n' < sysroot/etc/hostname)
lines=$(grep -c '^[[:space:]]*127\.0\.1\.1[[:space:]]' "$H")
if [ "$lines" -eq 0 ]; then
  echo "❌ sysroot/etc/hosts has no 127.0.1.1 line"
  exit 1
elif [ "$lines" -gt 1 ]; then
  echo "❌ sysroot/etc/hosts has $lines lines for 127.0.1.1, expected exactly one"
  exit 1
fi
first=$(awk '$1 == "127.0.1.1" { print $2; exit }' "$H")
if [ "$first" != "$HOST" ]; then
  echo "❌ the 127.0.1.1 line names '$first', but the server's hostname is another name (see sysroot/etc/hostname)"
  exit 1
fi
if ! grep -v '^[[:space:]]*127\.0\.1\.1[[:space:]]' "$H" | cmp -s - .lm-state/hosts-rest; then
  echo "❌ other lines of sysroot/etc/hosts changed; only the 127.0.1.1 line should differ"
  exit 1
fi
echo "✅ sysroot/etc/hosts maps 127.0.1.1 to $HOST and nothing else changed"
exit 0
