#!/bin/bash
# Three Shards, Three Answers: three import shards with randomised data, so
# each run returns a different exit status (0 clean, 3 rejected rows,
# 4 duplicate keys). import.sh logs start/end times for the overlap check.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p shards logs

cat > README.txt <<'TXT'
import.sh SHARD   imports shards/SHARD.csv into the customer database.
Exit status:
  0  every row imported
  3  some rows rejected (missing e-mail); the rest is imported, morning team fixes them
  4  duplicate customer ids: NOTHING imported, the shard must be rerun after cleanup
  5  shard file missing or unreadable
Each run appends "start ..." and "end ... exit=N" to logs/import-SHARD.log.
A shard takes 8 to 14 seconds.
TXT

cat > import.sh <<'SH'
#!/bin/bash
# Import one shard of customer data. Usage: import.sh eu|us|apac
case "$0" in
  /*) ;;
  *) exec "$(cd "$(dirname "$0")" && pwd)/$(basename "$0")" "$@" ;;
esac
HERE="$(dirname "$0")"
shard="${1:?usage: import.sh SHARD}"
csv="$HERE/shards/$shard.csv"
log="$HERE/logs/import-$shard.log"
echo "start $shard pid=$$ $EPOCHREALTIME" >> "$log"
if [ ! -r "$csv" ]; then
  echo "end $shard pid=$$ $EPOCHREALTIME exit=5" >> "$log"
  exit 5
fi
rows=$(($(wc -l < "$csv") - 1))
sleep $((8 + rows % 7))
dups=$(tail -n +2 "$csv" | cut -d, -f1 | sort | uniq -d | wc -l)
rejected=$(tail -n +2 "$csv" | awk -F, '$3 == ""' | wc -l)
if [ "$dups" -gt 0 ]; then
  code=4
elif [ "$rejected" -gt 0 ]; then
  code=3
else
  code=0
fi
echo "end $shard pid=$$ $EPOCHREALTIME exit=$code" >> "$log"
exit $code
SH
chmod 755 import.sh

# Give each shard a different outcome, in random order.
outcomes=(clean rejected duplicate)
for i in 2 1; do
  j=$((RANDOM % (i + 1)))
  tmp="${outcomes[$i]}"; outcomes[$i]="${outcomes[$j]}"; outcomes[$j]="$tmp"
done
names=(eu us apac)
first=(Ana Bram Chen Dara Emil Fatou Goran Hana Ivo Jun Kemal Lea Mio Nils Omar Pia)
for k in 0 1 2; do
  shard="${names[$k]}"
  rows=$((20 + RANDOM % 15))
  bad=$((1 + RANDOM % (rows - 2)))
  {
    echo "id,name,email"
    for ((r = 1; r <= rows; r++)); do
      id=$(( (k + 1) * 10000 + r * 7 ))
      name="${first[$(( (r + k * 5) % 16 ))]}"
      email="$(echo "$name" | tr 'A-Z' 'a-z').$id@example.com"
      case "${outcomes[$k]}" in
        rejected) [ "$r" -eq "$bad" ] && email="" ;;
        duplicate) [ "$r" -eq "$bad" ] && id=$(( (k + 1) * 10000 + 7 )) ;;
      esac
      echo "$id,$name,$email"
    done
  } > "shards/$shard.csv"
done
