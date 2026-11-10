#!/bin/bash
# What is on this disk? A failed VM left disk.img: a DOS partition table with
# 1-3 primary partitions, an extended container (number P+1) and 2-3 logical
# partitions numbered from 5. Everything is laid out on whole MiB, but the
# counts, sizes, gaps and type ids change on every run. The extended container
# is sometimes type 5 and sometimes type f. Validator reads the image itself.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

pick() { local a=("$@"); echo "${a[RANDOM % ${#a[@]}]}"; }

P=$((1 + RANDOM % 3))          # primaries
L=$((2 + RANDOM % 2))          # logicals
script="label: dos"$'\n'
pos=1                          # MiB
for ((i = 1; i <= P; i++)); do
  size=$((8 + 8 * (RANDOM % 6)))
  type=$(pick 83 83 82 07 0c 8e)
  script+="disk.img$i : start=$((pos * 2048)), size=$((size * 2048)), type=$type"$'\n'
  pos=$((pos + size + RANDOM % 3))
done
ext_start=$pos
ext_type=$(pick 5 f)
lines=""
lpos=$((ext_start + 1))
for ((j = 0; j < L; j++)); do
  size=$((8 + 8 * (RANDOM % 5)))
  type=$(pick 83 83 83 8e 82)
  lines+="disk.img$((5 + j)) : start=$((lpos * 2048)), size=$((size * 2048)), type=$type"$'\n'
  lpos=$((lpos + size + 1))
done
ext_size=$((lpos - 1 - ext_start))
script+="disk.img$((P + 1)) : start=$((ext_start * 2048)), size=$((ext_size * 2048)), type=$ext_type"$'\n'
script+="$lines"

truncate -s "$((lpos + 2))M" disk.img
printf '%s' "$script" | sfdisk -q disk.img >/dev/null 2>&1 || { echo "setup: sfdisk failed" >&2; exit 1; }
sfdisk -d disk.img > .lm-state/table

cat > TICKET.txt <<'EOF'
From: vm-ops
Subject: vm-0417 will not boot, please inventory its disk

The VM was powered off during a resize and now its boot loader finds nothing.
We pulled the disk as disk.img. Before anyone touches it: which partitions are
on it? Sector size is 512 bytes. Do not modify disk.img.
EOF
