#!/bin/bash
# Bad Dump Night: eight bzip2 SQL dumps, one truncated and one with a flipped
# bit (chosen at random). The player tests them, quarantines the bad ones and
# restores the rest.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p dumps quarantine restore .lm-state

tables=(customers orders order_items products invoices payments shipments stock_moves)
for t in "${tables[@]}"; do
  awk -v t="$t" -v seed="$RANDOM$RANDOM" 'BEGIN {
    srand(seed)
    print "-- MariaDB dump 10.19  Host: db-old   Database: shop"
    printf "DROP TABLE IF EXISTS `%s`;\nCREATE TABLE `%s` (id INT PRIMARY KEY, ref VARCHAR(16), val DECIMAL(10,2), note TEXT);\n", t, t
    printf "LOCK TABLES `%s` WRITE;\n", t
    n = 4000 + int(rand() * 4000)
    for (i = 1; i <= n; i++)
      printf "INSERT INTO `%s` VALUES (%d,\x27%08X\x27,%.2f,\x27batch %d node %d\x27);\n", t, i, int(rand()*4294967295), rand()*5000, int(rand()*90), int(rand()*7)
    print "UNLOCK TABLES;"
    print "-- Dump completed"
  }' > "dumps/$t.sql"
  echo "$t.sql $(cksum < "dumps/$t.sql")" >> .lm-state/sql.sums
  bzip2 -9 "dumps/$t.sql"
done

# Pick two different victims.
a=$(( RANDOM % 8 )); b=$(( (a + 1 + RANDOM % 7) % 8 ))
trunc="dumps/${tables[$a]}.sql.bz2"
flip="dumps/${tables[$b]}.sql.bz2"

# Truncated: the transfer stopped at about 60 %. The header is still fine.
size=$(wc -c < "$trunc" | tr -d ' ')
head -c $(( size * 6 / 10 )) "$trunc" > .lm-state/tmp && mv .lm-state/tmp "$trunc"

# Bit flip somewhere in the middle; retry in the unlikely case bzip2 misses it.
size=$(wc -c < "$flip" | tr -d ' ')
for try in 1 2 3 4 5; do
  pos=$(( size / 3 + RANDOM % (size / 3) ))
  byte=$(od -An -tu1 -j "$pos" -N1 "$flip" | tr -d ' ')
  printf "\\$(printf '%03o' $(( byte ^ 4 )))" | dd of="$flip" bs=1 seek="$pos" conv=notrunc 2>/dev/null
  bzip2 -t "$flip" 2>/dev/null || break
done

echo "${tables[$a]}.sql.bz2 ${tables[$b]}.sql.bz2" > .lm-state/bad
for f in dumps/*.bz2; do
  echo "$(basename "$f") $(cksum < "$f")" >> .lm-state/bz2.sums
done
