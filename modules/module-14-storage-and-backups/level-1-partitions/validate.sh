#!/bin/bash
# partitions.txt: "num start_sector size_MiB type" for every data partition of
# disk.img (the extended container is not one). Expected rows come from the image.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if ! sfdisk -d disk.img 2>/dev/null | cmp -s - .lm-state/table; then
  echo "❌ disk.img was changed or damaged; type 'reset' to get a fresh copy"
  exit 1
fi
if [ ! -f partitions.txt ]; then
  echo "❌ partitions.txt does not exist yet"
  exit 1
fi

norm='{ t = tolower($0); sub(/0x/, "", t); sub(/^0+/, "", t); if (t == "") t = "0"; print t }'
WANT=$(sfdisk -d disk.img | sed 's/= */=/g; s/,/ /g' | awk '
  /^disk\.img[0-9]+ :/ {
    n = $1; sub(/disk\.img/, "", n)
    for (i = 3; i <= NF; i++) { split($i, kv, "="); v[kv[1]] = kv[2] }
    t = tolower(v["type"]); sub(/^0+/, "", t)
    if (t == "5" || t == "f" || t == "85") { print "EXT " n; next }
    print n, v["start"], v["size"] / 2048, t
  }')
EXT=$(printf '%s\n' "$WANT" | awk '$1 == "EXT" { print $2 }')
WANT=$(printf '%s\n' "$WANT" | grep -v '^EXT ' | sort -n)

GOT=$(tr -d '\r' < partitions.txt | awk 'NF' | awk '{ $1 = $1; print }')
if [ -z "$GOT" ]; then
  echo "❌ partitions.txt is empty"
  exit 1
fi

ln=0
while IFS= read -r row; do
  ln=$((ln + 1))
  set -- $row
  if [ $# -ne 4 ] || [[ ! $1 =~ ^[0-9]+$ ]] || [[ ! $2 =~ ^[0-9]+$ ]] || [[ ! $3 =~ ^[0-9]+$ ]]; then
    echo "❌ line $ln of partitions.txt is not 'num start_sector size_MiB type' with plain numbers"
    exit 1
  fi
  num=$1; t=$(printf '%s\n' "$4" | awk "$norm")
  if [ "$num" = "$EXT" ]; then
    echo "❌ partition $num is the extended container: it only holds the logical partitions, it is not a data partition"
    exit 1
  fi
  w=$(printf '%s\n' "$WANT" | awk -v n="$num" '$1 == n')
  if [ -z "$w" ]; then
    echo "❌ there is no data partition number $num on disk.img"
    exit 1
  fi
  set -- $w
  if [ "$2" != "$(printf '%s' "$row" | awk '{print $2}')" ]; then
    echo "❌ partition $num: the start sector is not what the partition table says"
    exit 1
  fi
  if [ "$3" != "$(printf '%s' "$row" | awk '{print $3}')" ]; then
    echo "❌ partition $num: the size is wrong (the column is MiB, one MiB is 2048 sectors of 512 bytes)"
    exit 1
  fi
  if [ "$4" != "$t" ]; then
    echo "❌ partition $num: the type id does not match the partition table"
    exit 1
  fi
done <<< "$GOT"

if [ "$(printf '%s\n' "$GOT" | cut -d' ' -f1 | sort -n | uniq | wc -l)" -ne "$(printf '%s\n' "$GOT" | wc -l)" ]; then
  echo "❌ a partition number appears more than once in partitions.txt"
  exit 1
fi
have=$(printf '%s\n' "$GOT" | wc -l); need=$(printf '%s\n' "$WANT" | wc -l)
if [ "$have" -ne "$need" ]; then
  echo "❌ partitions.txt lists $have partitions, but the disk has more data partitions than that (logical ones start at number 5)"
  exit 1
fi
echo "✅ partitions.txt matches the partition table: $need data partitions, extended container left out"
exit 0
