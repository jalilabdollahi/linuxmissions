#!/bin/bash
# $1 = sandbox path
# A shop backup, cut into 14 byte-pieces by the transfer tool. Part 7 was sent
# twice: the first, truncated attempt is still lying around as "backup.part7 (copy)".
SANDBOX="$1"
cd "$SANDBOX" || exit 1

B=.build
mkdir -p "$B/shop/db" "$B/shop/config" "$B/shop/uploads/2026-10" "$B/shop/uploads/2026-11"

# A text dump with random rows, so every setup gives a different archive
{
  echo "-- shop database dump, $(date -u +%Y-%m-%d)"
  echo "CREATE TABLE orders (id INT PRIMARY KEY, customer INT, total_cents INT, status TEXT);"
  for i in $(seq 1 2500); do
    echo "INSERT INTO orders VALUES ($((70000 + i)), $((RANDOM % 900 + 100)), $((RANDOM * 7 % 99999)), 'paid');"
  done
} > "$B/shop/db/shop.sql"
printf 'listen 8080\nworkers %d\ncache_dir /var/cache/shop\n' $((RANDOM % 8 + 2)) > "$B/shop/config/shop.conf"
printf 'DB_HOST=db-01.internal\nDB_NAME=shop\n' > "$B/shop/config/db.env"
printf 'User-agent: *\nDisallow: /admin\n' > "$B/shop/robots.txt"

# Product photos: random bytes do not compress, so the archive stays big
for m in 2026-10 2026-11; do
  for n in 1 2 3 4 5 6; do
    head -c $(( (RANDOM % 90 + 40) * 1024 )) /dev/urandom > "$B/shop/uploads/$m/product-$((RANDOM % 9000 + 1000))-$n.jpg"
  done
done

tar -czf "$B/backup.tar.gz" -C "$B" shop
if command -v sha256sum >/dev/null 2>&1; then
  ( cd "$B" && sha256sum backup.tar.gz ) > backup.tar.gz.sha256
else
  ( cd "$B" && shasum -a 256 backup.tar.gz ) > backup.tar.gz.sha256
fi

# Cut into exactly 14 pieces: backup.part1 ... backup.part14
size=$(wc -c < "$B/backup.tar.gz" | tr -d ' ')
chunk=$(( (size + 13) / 14 ))
i=0
while [ $(( i * chunk )) -lt "$size" ]; do
  i=$((i + 1))
  dd if="$B/backup.tar.gz" of="backup.part$i" bs="$chunk" skip=$((i - 1)) count=1 2>/dev/null
done

# The first, broken attempt at part 7: only the first 60% arrived
head -c $(( $(wc -c < backup.part7) * 6 / 10 )) backup.part7 > "backup.part7 (copy)"

cat > transfer.log <<EOF
2026-11-10 03:12:01 send backup.tar.gz to restore-host in 14 parts ($size bytes)
2026-11-10 03:12:09 part 1/14 ok
2026-11-10 03:12:40 part 7/14 connection reset at 60% -> kept as "backup.part7 (copy)"
2026-11-10 03:12:44 part 7/14 retry ok
2026-11-10 03:13:30 part 14/14 ok
2026-11-10 03:13:30 checksum of the whole file: backup.tar.gz.sha256
EOF
rm -rf "$B"
