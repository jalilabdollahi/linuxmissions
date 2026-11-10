#!/bin/bash
# Probe every image directly (-p); a PTTYPE answer means a partition table, so read
# the table with sfdisk -d and probe each partition at its byte offset (-O).
echo 'file,TYPE,UUID,LABEL' > inventory.csv
probe() {  # name file [offset]
  blkid -p -o export ${3:+-O "$3"} "$2" 2>/dev/null |
    awk -F= -v n="$1" '$1=="TYPE"{t=$2} $1=="UUID"{u=$2} $1=="LABEL"{l=$2} END{print n "," t "," u "," l}'
}
(cd images && for f in *.img; do
  if blkid -p -o export "$f" 2>/dev/null | grep -q '^PTTYPE='; then
    sfdisk -d "$f" | awk -v f="$f" '/start=/ {n++; gsub(",","",$4); print f "@p" n, $4*512}' |
      while read -r name off; do probe "$name" "$f" "$off"; done
  else
    probe "$f" "$f"
  fi
done) >> inventory.csv
cat inventory.csv
