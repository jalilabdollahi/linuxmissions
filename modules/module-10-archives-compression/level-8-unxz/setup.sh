#!/bin/bash
# Size Before You Unpack: five xz exports of random size. `xz -l` shows rounded
# KiB/MiB; the exact byte total needs --robot (or -vv), or decompressing to a pipe.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p exports .lm-state

total=0
for t in customers orders order_lines products sessions; do
  awk -v t="$t" -v seed="$RANDOM$RANDOM" 'BEGIN {
    srand(seed)
    printf "-- pg_dump export of public.%s\nCOPY public.%s (id, key, amount, created_at, tag) FROM stdin;\n", t, t
    n = 6000 + int(rand() * 20000)
    for (i = 1; i <= n; i++)
      printf "%d\t%s-%07d\t%.2f\t2026-%02d-%02d %02d:%02d:%02d\t%s\n", i, substr(t, 1, 3), int(rand()*9999999), rand()*999,
        1 + int(rand()*10), 1 + int(rand()*28), int(rand()*24), int(rand()*60), int(rand()*60), (rand() < 0.2 ? "vip" : "std")
    print "\\."
  }' > "exports/$t.sql"
  size=$(wc -c < "exports/$t.sql" | tr -d ' ')
  total=$(( total + size ))
  [ "$t" = customers ] && cksum < exports/customers.sql > .lm-state/customers.sum
  xz -6 "exports/$t.sql"
done
echo "$total" > .lm-state/total
for f in exports/*.xz; do
  echo "$(basename "$f") $(cksum < "$f")" >> .lm-state/xz.sums
done
