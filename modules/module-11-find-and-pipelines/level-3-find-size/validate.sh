#!/bin/bash
# oversize.txt = files > 10 MiB, empty.txt = 0-byte files (lists made by setup).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/oversize ] || [ ! -s .lm-state/empty ]; then
  echo "❌ the level's reference data in .lm-state/ is gone; type 'reset'"
  exit 1
fi
while IFS= read -r f; do
  if [ ! -f "$f" ]; then
    echo "❌ $f is gone from outbox/; type 'reset' to restore it"
    exit 1
  fi
done < <(cat .lm-state/oversize .lm-state/empty)

size_of() { wc -c < "$1" | tr -d ' '; }

check() {  # file reference kind
  local file=$1 want got line n
  want=$(LC_ALL=C sort "$2")
  if [ ! -f "$file" ]; then
    echo "❌ $file does not exist yet"
    exit 1
  fi
  got=$(tr -d '\r' < "$file" | sed -e "s|^$SANDBOX/||" -e 's|^\./||' | grep -v '^[[:space:]]*$' | LC_ALL=C sort)
  [ "$got" = "$want" ] && return 0
  if [ -n "$(printf '%s\n' "$got" | uniq -d)" ]; then
    echo "❌ $file lists a path more than once"
    exit 1
  fi
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    printf '%s\n' "$want" | grep -qxF -- "$line" && continue
    if [ -d "$line" ]; then
      echo "❌ $file lists $line, which is a directory, not a file"
    elif [ ! -f "$line" ]; then
      echo "❌ $file has a line that is not the path of a file under outbox/: $line"
    elif [ "$3" = big ]; then
      n=$(size_of "$line")
      if [ "$n" -eq 10485760 ]; then
        echo "❌ $file lists $line, which is exactly 10 MiB (10485760 bytes); the relay still accepts that"
      elif [ "$n" -ge 10000000 ]; then
        echo "❌ $file lists $line ($n bytes): over 10 MB, but not over 10 MiB = 10485760 bytes"
      else
        echo "❌ $file lists $line, which is only $n bytes"
      fi
    else
      echo "❌ $file lists $line, which is $(size_of "$line") byte(s), not 0"
    fi
    exit 1
  done <<< "$got"
  n=$(printf '%s\n' "$got" | grep -c .)
  echo "❌ $file lists $n file(s), but $(printf '%s\n' "$want" | wc -l | tr -d ' ') belong there"
  exit 1
}

check oversize.txt .lm-state/oversize big
check empty.txt .lm-state/empty empty
echo "✅ oversize.txt names the $(wc -l < .lm-state/oversize | tr -d ' ') attachments over 10 MiB and empty.txt the $(wc -l < .lm-state/empty | tr -d ' ') zero-byte files"
exit 0
