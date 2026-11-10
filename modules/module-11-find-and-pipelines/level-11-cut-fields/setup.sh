#!/bin/bash
# Columns for Two Audiences: a 14-column TSV export of ~400 servers. Values
# with spaces (so whitespace splitting breaks rows), empty notes fields, and
# the requested columns are not in file order (cut cannot reorder them).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM" 'BEGIN {
  srand(seed); OFS = "\t"
  split("PowerEdge R650|PowerEdge R750xs|ProLiant DL380 Gen10|ProLiant DL360 Gen11|ThinkSystem SR630|UCS C220 M6", model, "|")
  split("Dell|Dell|HPE|HPE|Lenovo|Cisco", vendor, "|")
  split("FRA1|FRA2|AMS1", site, "|")
  split("Hall A|Hall B|Cage 12|Room 0.14", room, "|")
  split("web db cache queue batch k8s-node", role, " ")
  split("anna.berg mehdi.karimi l.nguyen ops-team s.schulz j.ortiz p.novak", who, " ")
  split("|spare PSU ordered||rail kit missing|moved from FRA2||decommission Q1 2027|RAID battery replaced, check again|", note, "|")
  print "asset_id", "hostname", "model", "vendor", "serial", "site", "room", "row", "rack", "unit", "owner_email", "purchase_date", "warranty_end", "notes"
  for (i = 1; i <= 400; i++) {
    m = 1 + int(rand() * 6); s = 1 + int(rand() * 3)
    y = 2019 + int(rand() * 7); mo = 1 + int(rand() * 12); d = 1 + int(rand() * 28)
    printf "A-%05d\t%s-%02d.%s\t%s\t%s\t%s%07d\t%s\t%s\t%c\tR%02d\t%dU\t%s@example.com\t%d-%02d-%02d\t%d-%02d-%02d\t%s\n",
      10000 + i * 7, role[1 + int(rand() * 6)], i % 97, tolower(site[s]), model[m], vendor[m],
      substr("JCXMKH", m, 1) substr("ABCDEFGHJK", 1 + int(rand() * 10), 1), int(rand() * 9999999),
      site[s], room[1 + int(rand() * 4)], 65 + int(rand() * 6), 1 + int(rand() * 40), 1 + int(rand() * 42),
      who[1 + int(rand() * 7)], y, mo, d, y + 5, mo, d, note[1 + int(rand() * 9)]
  }
}' > assets.tsv
cksum < assets.tsv > .lm-state/assets.sum
