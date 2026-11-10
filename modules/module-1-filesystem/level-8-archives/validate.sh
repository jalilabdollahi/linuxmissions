#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -f backup.tar.gz ]; then
  echo "❌ backup.tar.gz is gone (it is needed to check your work); type 'reset'"
  exit 1
fi

# Part 1: every file from the backup is in extracted/, with the same content
if [ ! -d extracted ]; then
  echo "❌ extracted/ does not exist yet"
  exit 1
fi
for entry in $(tar -tzf backup.tar.gz | grep -v '/$'); do
  if [ ! -f "extracted/$entry" ]; then
    echo "❌ extracted/$entry is missing (extract the archive into extracted/ as it is)"
    exit 1
  fi
  if ! tar -xzOf backup.tar.gz "$entry" | cmp -s - "extracted/$entry"; then
    echo "❌ extracted/$entry differs from the copy in the backup"
    exit 1
  fi
done

# Part 2: archive.tar.gz holds exactly the .log files from logs/
if [ ! -f archive.tar.gz ]; then
  echo "❌ archive.tar.gz does not exist yet"
  exit 1
fi
if ! gzip -t archive.tar.gz 2>/dev/null; then
  echo "❌ archive.tar.gz is not gzip-compressed (tar needs -z to compress)"
  exit 1
fi
entries=$(tar -tzf archive.tar.gz 2>/dev/null | grep -v '/$')
got=$(printf '%s\n' "$entries" | sed 's|.*/||' | grep -v '^$' | LC_ALL=C sort | tr '\n' ' ')
want=$(cd logs && ls -1 -- *.log | LC_ALL=C sort | tr '\n' ' ')
if [ "$got" != "$want" ]; then
  n=$(printf '%s\n' "$entries" | grep -c .)
  echo "❌ archive.tar.gz has $n file(s); it should hold exactly the .log files from logs/ ($(echo "$want" | wc -w | tr -d ' ') files)"
  exit 1
fi
for entry in $entries; do
  if ! tar -xzOf archive.tar.gz "$entry" | cmp -s - "logs/${entry##*/}"; then
    echo "❌ ${entry##*/} inside archive.tar.gz differs from logs/${entry##*/}"
    exit 1
  fi
done
echo "✅ backup restored to extracted/ and archive.tar.gz holds the $(echo "$want" | wc -w | tr -d ' ') .log files"
exit 0
