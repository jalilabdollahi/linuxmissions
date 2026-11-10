#!/bin/bash
# import/ = one plain CSV per inbox/*.csv.gz; inbox/ exactly as delivered.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/csv.sums ] || [ ! -s .lm-state/inbox.sums ]; then
  echo "❌ the level's reference data in .lm-state/ is gone; type 'reset'"
  exit 1
fi

while read -r name sum size; do
  if [ ! -f "inbox/$name" ]; then
    case "$name" in
      *.gz) if [ -f "inbox/${name%.gz}" ] || [ -f "import/${name%.gz}" ]; then
              echo "❌ inbox/$name is gone: plain gunzip deletes the .gz after unpacking. Compliance needs it (type 'reset')"
            else
              echo "❌ inbox/$name is gone; type 'reset' to get the delivery back"
            fi ;;
      *) echo "❌ inbox/$name is gone; leave inbox/ as it was delivered (type 'reset')" ;;
    esac
    exit 1
  fi
  if [ "$(cksum < "inbox/$name")" != "$sum $size" ]; then
    echo "❌ inbox/$name was changed; the audit trail needs it exactly as delivered (type 'reset')"
    exit 1
  fi
done < .lm-state/inbox.sums
stray=$(cd inbox && ls -A | grep -vxF -f <(awk '{print $1}' "$SANDBOX/.lm-state/inbox.sums") | head -1)
if [ -n "$stray" ]; then
  echo "❌ inbox/$stray was not part of the delivery; the CSVs belong in import/, not inbox/"
  exit 1
fi

if [ ! -d import ]; then
  echo "❌ import/ does not exist"
  exit 1
fi
want=$(awk '{print $1}' .lm-state/csv.sums | LC_ALL=C sort)
got=$(cd import && ls -A | LC_ALL=C sort)
if [ -z "$got" ]; then
  echo "❌ import/ is still empty"
  exit 1
fi
if [ "$got" != "$want" ]; then
  missing=$(comm -23 <(printf '%s\n' "$want") <(printf '%s\n' "$got") | head -1)
  extra=$(comm -13 <(printf '%s\n' "$want") <(printf '%s\n' "$got") | head -1)
  if [ -n "$extra" ]; then
    echo "❌ import/$extra should not be there; import/ needs exactly one NAME.csv per inbox/NAME.csv.gz"
  else
    echo "❌ import/$missing is missing"
  fi
  exit 1
fi
while read -r name sum size; do
  if [ "$(cksum < "import/$name")" != "$sum $size" ]; then
    if gzip -t "import/$name" 2>/dev/null; then
      echo "❌ import/$name is still gzip-compressed; the import job needs plain text"
    else
      echo "❌ import/$name does not match the content of inbox/$name.gz"
    fi
    exit 1
  fi
done < .lm-state/csv.sums
echo "✅ $(echo "$want" | wc -l | tr -d ' ') CSVs are in import/ and inbox/ is untouched"
exit 0
