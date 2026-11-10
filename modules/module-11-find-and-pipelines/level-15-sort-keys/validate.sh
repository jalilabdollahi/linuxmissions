#!/bin/bash
# sorted.txt = the header, then every row of inventory.txt ordered by dc
# (A-Z), load (as a number, highest first), host (natural order: web9 < web10).
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/inventory.sum ] || [ "$(cksum < inventory.txt 2>/dev/null)" != "$(cat .lm-state/inventory.sum)" ]; then
  echo "❌ inventory.txt was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f sorted.txt ]; then
  echo "❌ sorted.txt does not exist yet"
  exit 1
fi

GOT=$(tr -d '\r' < sorted.txt | grep -v '^[[:space:]]*$')
EXPECTED=$(head -1 inventory.txt; tail -n +2 inventory.txt | sort -k2,2 -k4,4gr -k1,1V)
if [ "$GOT" = "$EXPECTED" ]; then
  echo "✅ sorted.txt: $(( $(printf '%s\n' "$EXPECTED" | wc -l) - 1 )) hosts by datacenter, load (highest first) and host"
  exit 0
fi

if [ "$(printf '%s\n' "$GOT" | head -1)" != "host dc rack load mem" ]; then
  if printf '%s\n' "$GOT" | grep -qx 'host dc rack load mem'; then
    echo "❌ the header line was sorted in with the data; it must stay the first line"
  else
    echo "❌ sorted.txt must start with the header line from inventory.txt"
  fi
  exit 1
fi
if [ "$(printf '%s\n' "$GOT" | tail -n +2 | sort)" != "$(tail -n +2 inventory.txt | sort)" ]; then
  echo "❌ the rows in sorted.txt are not exactly the rows of inventory.txt (each row once, unchanged)"
  exit 1
fi
# Rows are right, the order isn't. Recognise the classic slips first.
rows() { tail -n +2 inventory.txt | sort "$@"; }
if [ "$GOT" = "$(head -1 inventory.txt; rows -k2 -k4,4gr -k1,1V)" ]; then
  echo "❌ inside each datacenter the rows are ordered by rack, not by load: a key like -k2 runs from field 2 to the end of the line"
  exit 1
fi
if [ "$GOT" = "$(head -1 inventory.txt; rows -k2,2 -k4,4nr -k1,1V)" ]; then
  echo "❌ some loads are written in scientific notation (1e-02 = 0.01, 1.2e+01 = 12) and were compared as plain numbers: 1.2e+01 counted as 1.2"
  exit 1
fi
# Otherwise walk the rows and report the first rule that is broken.
msg=$(printf '%s\n' "$GOT" | tail -n +2 | awk '
  NR > 1 && $2 < pdc { print "❌ " $1 " (" $2 ") comes after " ph " (" pdc "): the datacenters must be in alphabetical order"; exit }
  NR > 1 && $2 == pdc && $4 + 0 > pl + 0 { print "❌ in " $2 ", " ph " (load " pl ") comes before " $1 " (load " $4 "): compare loads by value, highest first (1.2e+01 is 12)"; exit }
  { pdc = $2; pl = $4; ph = $1 }')
if [ -n "$msg" ]; then
  echo "$msg"
  exit 1
fi
pair=$(printf '%s\n' "$GOT" | tail -n +2 | awk 'NR > 1 && $2 == pdc && $4 + 0 == pl + 0 { print ph, $1 } { pdc = $2; pl = $4; ph = $1 }' \
  | while read -r a b; do
      if [ "$(printf '%s\n%s\n' "$a" "$b" | sort -V | head -1)" != "$a" ]; then echo "$a $b"; break; fi
    done)
if [ -n "$pair" ]; then
  echo "❌ ${pair% *} comes before ${pair#* } although both have the same datacenter and load: hosts must be in natural order (web9 before web10)"
  exit 1
fi
echo "❌ the order of sorted.txt is not right yet"
exit 1
