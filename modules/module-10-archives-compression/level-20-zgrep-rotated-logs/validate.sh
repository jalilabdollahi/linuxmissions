#!/bin/bash
# $1 = sandbox path
# Expected: every line whose order= field is exactly 88412, from app.log.14
# (oldest) down to app.log (newest). The rotated files must still be there,
# compressed and intact, with no unpacked copies lying around.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

rotated() {  # file names oldest first
  local n
  for n in 14 13; do echo "app.log.$n.xz"; done
  for n in 12 11; do echo "app.log.$n.bz2"; done
  for n in 10 9 8 7 6 5 4 3 2; do echo "app.log.$n.gz"; done
}
unpack() {  # decompress one rotated log to stdout
  case $1 in
    *.gz)  gzip -dc "$1" ;;
    *.bz2) bzip2 -dc "$1" ;;
    *.xz)  xz -dc "$1" ;;
  esac
}
for f in $(rotated) app.log.1 app.log; do
  if [ ! -f "logs/$f" ]; then
    echo "❌ logs/$f is gone (decompressed in place?); the rotated logs must stay as they are. Type 'reset'"
    exit 1
  fi
done
for f in $(rotated); do
  case $f in
    *.gz)  gzip -t "logs/$f" 2>/dev/null ;;
    *.bz2) bzip2 -t "logs/$f" 2>/dev/null ;;
    *.xz)  xz -t "logs/$f" 2>/dev/null ;;
  esac || { echo "❌ logs/$f is no longer a valid compressed file; type 'reset'"; exit 1; }
done
extra=$(cd logs && ls -A | grep -vxF -e "$( (rotated; echo app.log.1; echo app.log) )" | head -1)
if [ -n "$extra" ]; then
  echo "❌ logs/ has an extra file '$extra'; search the compressed logs without unpacking them to disk"
  exit 1
fi
copy=$(find . -path ./logs -prune -o -type f -name 'app.log*' -print | head -1)
if [ -n "$copy" ]; then
  echo "❌ found an unpacked copy $copy; search the compressed logs in place instead"
  exit 1
fi

if [ ! -f order-88412.txt ]; then
  echo "❌ order-88412.txt does not exist yet"
  exit 1
fi

expected=$(
  for f in $(rotated); do unpack "logs/$f"; done | grep -E 'order=88412( |$)'
  grep -hE 'order=88412( |$)' logs/app.log.1 logs/app.log
)
got=$(tr -d '\r' < order-88412.txt | grep -v '^$')
n_want=$(printf '%s\n' "$expected" | grep -c .)

if [ "$got" = "$expected" ]; then
  echo "✅ order-88412.txt has all $n_want lines about order 88412, oldest first"
  exit 0
fi
if printf '%s\n' "$got" | grep -Eq '^(logs/)?app\.log[^ ]*:'; then
  echo "❌ the lines start with file names; write only the log lines themselves (grep -h)"
elif printf '%s\n' "$got" | grep -vEq 'order=88412( |$)'; then
  other=$(printf '%s\n' "$got" | grep -vE 'order=88412( |$)' | grep -o 'order=[0-9]*\|amount_cents=[0-9]*' | head -1)
  echo "❌ order-88412.txt has lines about other orders (e.g. ${other:-lines without order=88412}); 88412 must be the whole order= value"
elif [ "$(printf '%s\n' "$got" | sort)" = "$(printf '%s\n' "$expected" | sort)" ]; then
  echo "❌ the right $n_want lines, but not oldest first (app.log.14 is the oldest file, app.log the newest)"
else
  n_got=$(printf '%s\n' "$got" | grep -c .)
  if [ "$n_got" -lt "$n_want" ]; then
    echo "❌ order-88412.txt has $n_got lines about order 88412, there are $n_want (were the .bz2 and .xz logs searched too?)"
  else
    echo "❌ order-88412.txt has $n_got lines, but there are $n_want lines about order 88412 (each one once)"
  fi
fi
exit 1
