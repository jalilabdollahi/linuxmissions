#!/bin/bash
# Scanner Dump: the dock's old handheld scanner writes every parcel as four
# lines (parcel id, weight in kg, postcode, dock door) and a "--" line after
# each parcel except the last. The batches synced through the Windows PC have
# CRLF line endings, separators included. Random per setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
function digits(k,   s, i) { s = ""; for (i = 0; i < k; i++) s = s int(rand() * 10); return s }
function letter() { return substr("ABCDEFGHJKLMNPRSTUWXYZ", int(rand() * 22) + 1, 1) }
BEGIN {
  srand(seed)
  np = split("SW1A 1AA|EC2V 7HH|M1 4BT|LS1 5DL|B2 4QA|G2 8DL|BS1 6QF|CF10 1EP|NE1 7RU|L3 9PP|EH1 2NG|OX1 3BG|CB2 1TN|NG1 5FS|S1 2HE|BT1 5GS", pc, "|")
  n = 110 + int(rand() * 40)
  # two batches came through the Windows PC
  c1 = 10 + int(rand() * 30); c2 = c1 + 15 + int(rand() * 20)
  for (i = 1; i <= n; i++) {
    r = rand()
    if (r < 0.5) id = letter() letter() digits(9) "GB"
    else if (r < 0.8) id = "1550" digits(10)
    else id = "H" digits(15)
    w = (rand() < 0.2) ? sprintf("%.2f", 0.1 + rand()) : sprintf("%.2f", 1 + rand() * 24)
    p = pc[int(rand() * np) + 1]
    sub(/[0-9][A-Z][A-Z]$/, int(rand() * 10) letter() letter(), p)
    dock = "D" (int(rand() * 6) + 1)
    eol = ((i >= c1 && i < c1 + 12) || (i >= c2 && i < c2 + 9)) ? "\r\n" : "\n"
    printf "%s%s%s%s%s%s%s%s", id, eol, w, eol, p, eol, dock, eol
    if (i < n) printf "--%s", eol
  }
}' > scan_dump.txt

cksum < scan_dump.txt > .lm-state/dump.sum
