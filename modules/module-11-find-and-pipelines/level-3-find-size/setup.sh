#!/bin/bash
# Too Big to Send: attachments of every size in outbox/msg-*/ (sparse files, so
# they cost no disk). Around the limit: exactly 10 MiB (allowed), 10,000,000
# and 10,200,000 bytes ("10 MB" but under 10 MiB), 10 MiB + 1 byte (too big).
# Zero-byte failed writes, one hidden; a 1-byte file and empty folders as decoys.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p outbox/deferred outbox/retry .lm-state

MiB=1048576
mk() {  # mk PATH BYTES
  mkdir -p "$(dirname "$1")"
  if [ "$2" -eq 0 ]; then : > "$1"; else
    dd if=/dev/zero of="$1" bs=1 count=0 seek="$2" 2>/dev/null
    printf 'x' | dd of="$1" bs=1 seek=0 conv=notrunc 2>/dev/null
  fi
}

names=("Q3 board deck.pptx" "site walkthrough.mp4" "contract-signed.pdf" "invoice 4471.pdf"
  "floorplan.dwg" "team photo.jpg" "db-export.csv.gz" "logo.svg" "press kit.zip"
  "drone footage.mov" "scan_0012.tiff" "minutes.docx" "budget 2027.xlsx" "render-final.png"
  "audit-trail.log" "handbook.pdf" "keynote rehearsal.m4a" "dataset.parquet" "notes.txt"
  "backup.tar" "signature.png" "offer letter.pdf" "survey results.xlsx" "promo.gif")
# Special sizes for the first 13 shuffled names; the rest get ordinary sizes.
sizes=($((10 * MiB + 1)) 10500000 $((14 * MiB)) $((25 * MiB + 333)) 54001234
       $((10 * MiB)) 10000000 10200000 $((9 * MiB + 900000))
       0 0 0 1)
order=$(awk -v seed="$RANDOM" -v n="${#names[@]}" 'BEGIN { srand(seed)
  for (i = 0; i < n; i++) a[i] = i
  for (i = n - 1; i > 0; i--) { j = int(rand() * (i + 1)); t = a[i]; a[i] = a[j]; a[j] = t }
  for (i = 0; i < n; i++) print a[i] }')

: > .lm-state/oversize; : > .lm-state/empty
k=0
for idx in $order; do
  msg=$(printf 'outbox/msg-%04d' $(( 1000 + RANDOM % 9000 )))
  while [ -e "$msg" ]; do msg="$msg-b"; done
  f="$msg/${names[$idx]}"
  if [ $k -lt ${#sizes[@]} ]; then sz=${sizes[$k]}; else sz=$(( (RANDOM * 37 + k * 4099) % (6 * MiB) + 2048 )); fi
  mk "$f" "$sz"
  printf 'From: user%d@example.com\nSubject: %s\n\nsee attachment\n' $k "${names[$idx]}" > "$msg/message.eml"
  [ "$sz" -gt $((10 * MiB)) ] && echo "$f" >> .lm-state/oversize
  [ "$sz" -eq 0 ] && echo "$f" >> .lm-state/empty
  k=$((k + 1))
done

# A hidden half-written upload, and empty folders that are not files.
last=$(ls -d outbox/msg-* | tail -1)
: > "$last/.upload.partial"; echo "$last/.upload.partial" >> .lm-state/empty
mkdir -p "$last/inline images"
