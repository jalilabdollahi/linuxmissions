#!/bin/bash
# total_bytes.txt = exact uncompressed total; customers.sql restored; all
# .xz files still there; no other plain export left.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
for f in total customers.sum xz.sums; do
  if [ ! -s ".lm-state/$f" ]; then
    echo "❌ the level's reference data in .lm-state/ is gone; type 'reset'"
    exit 1
  fi
done

while read -r name sum size; do
  if [ ! -f "exports/$name" ]; then
    echo "❌ exports/$name is gone; keep all five .xz files (unxz deletes them unless you keep them)"
    exit 1
  fi
  if [ "$(cksum < "exports/$name")" != "$sum $size" ]; then
    echo "❌ exports/$name was changed; type 'reset'"
    exit 1
  fi
done < .lm-state/xz.sums

if [ ! -f total_bytes.txt ]; then
  echo "❌ total_bytes.txt does not exist yet"
  exit 1
fi
answer=$(tr -d ' \t\r\n' < total_bytes.txt)
want=$(cat .lm-state/total)
case "$answer" in
  ''|*[!0-9]*)
    echo "❌ total_bytes.txt should hold just a number of bytes (digits only), not '$(head -c 40 total_bytes.txt | tr '\n' ' ')'"
    exit 1 ;;
esac
if [ "$answer" != "$want" ]; then
  diff=$(( answer > want ? answer - want : want - answer ))
  if [ $(( diff * 100 )) -lt "$want" ]; then
    echo "❌ total_bytes.txt says $answer, which is close but not exact (rounded KiB/MiB figures are not good enough)"
  else
    echo "❌ total_bytes.txt says $answer, which is not the total uncompressed size of the five exports"
  fi
  exit 1
fi

if [ ! -f exports/customers.sql ]; then
  echo "❌ the total is right; now restore exports/customers.sql"
  exit 1
fi
if [ "$(cksum < exports/customers.sql)" != "$(cat .lm-state/customers.sum)" ]; then
  echo "❌ exports/customers.sql does not match the content of customers.sql.xz"
  exit 1
fi
extra=$(cd exports && ls -A | grep -vxF -f <(awk '{print $1}' "$SANDBOX/.lm-state/xz.sums"; echo customers.sql) | head -1)
if [ -n "$extra" ]; then
  echo "❌ exports/$extra should not be there; only customers.sql is unpacked for now"
  exit 1
fi
echo "✅ total_bytes.txt has the exact total ($want bytes) and customers.sql is restored"
exit 0
