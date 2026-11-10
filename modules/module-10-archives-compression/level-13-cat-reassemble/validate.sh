#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

sha() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | cut -d' ' -f1
  else shasum -a 256 | cut -d' ' -f1; fi
}

for i in $(seq 1 14); do
  if [ ! -f "backup.part$i" ]; then
    echo "❌ backup.part$i is gone; the parts are needed to check your work (type 'reset')"
    exit 1
  fi
done
want=$(cat backup.part{1..14} | sha)
if [ "$want" != "$(cut -d' ' -f1 backup.tar.gz.sha256 2>/dev/null)" ]; then
  echo "❌ the parts or backup.tar.gz.sha256 were changed; type 'reset' to get them back"
  exit 1
fi

if [ ! -f backup.tar.gz ]; then
  echo "❌ backup.tar.gz has not been rebuilt yet"
  exit 1
fi
if [ "$(sha < backup.tar.gz)" != "$want" ]; then
  got=$(wc -c < backup.tar.gz | tr -d ' ')
  parts=$(cat backup.part{1..14} | wc -c | tr -d ' ')
  copy=$(wc -c < "backup.part7 (copy)" | tr -d ' ')
  if [ "$got" -eq $((parts + copy)) ]; then
    echo "❌ backup.tar.gz is $got bytes: it includes the broken 'backup.part7 (copy)'"
  elif [ "$got" -eq "$parts" ]; then
    echo "❌ backup.tar.gz has the right size but a wrong checksum: the parts are joined in the wrong order (how does the shell sort part10 and part2?)"
  else
    echo "❌ backup.tar.gz is $got bytes, but the 14 parts add up to $parts bytes"
  fi
  exit 1
fi

if [ ! -d restored/shop ]; then
  echo "❌ the checksum matches; now extract backup.tar.gz into restored/ (so that restored/shop/ exists)"
  exit 1
fi
members=$(tar -tzf backup.tar.gz | grep -v '/$')
for m in $members; do
  if [ ! -f "restored/$m" ]; then
    echo "❌ restored/$m is missing"
    exit 1
  fi
  if ! tar -xzOf backup.tar.gz "$m" | cmp -s - "restored/$m"; then
    echo "❌ restored/$m differs from the copy in backup.tar.gz"
    exit 1
  fi
done
n_want=$(printf '%s\n' "$members" | grep -c .)
n_got=$(find restored -type f | wc -l | tr -d ' ')
if [ "$n_got" -ne "$n_want" ]; then
  echo "❌ restored/ has $n_got files, but the backup holds $n_want; extract only backup.tar.gz there"
  exit 1
fi
echo "✅ backup.tar.gz matches its sha256 and all $n_want files are restored"
exit 0
