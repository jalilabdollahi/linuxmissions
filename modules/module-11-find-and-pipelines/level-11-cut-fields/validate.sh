#!/bin/bash
# inventory.tsv = serial, hostname, rack (fields 5, 2, 9) in that order;
# vendor.tsv = every field except 11 (owner_email). Header and all rows kept.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/assets.sum ]; then
  echo "❌ the level's reference data in .lm-state/ is gone; type 'reset'"
  exit 1
fi
if [ ! -f assets.tsv ] || [ "$(cksum < assets.tsv)" != "$(cat .lm-state/assets.sum)" ]; then
  echo "❌ assets.tsv was changed or removed; it must stay as it is (type 'reset')"
  exit 1
fi

check() {  # file want_fields description expected
  local file=$1 nf=$2 what=$3 want=$4 got first
  if [ ! -f "$file" ]; then
    echo "❌ $file does not exist yet"
    exit 1
  fi
  got=$(tr -d '\r' < "$file")
  [ "$got" = "$want" ] && return 0
  if [ -z "$got" ]; then
    echo "❌ $file is empty"
    exit 1
  fi
  if [ "$file" = vendor.tsv ] && printf '%s\n' "$got" | grep -q -e '@example\.com' -e 'owner_email'; then
    echo "❌ vendor.tsv still contains the owner_email column"
    exit 1
  fi
  if [ "$(printf '%s\n' "$got" | head -1)" = "$(printf '%s\n' "$want" | head -1 | tr '\t' ' ')" ]; then
    echo "❌ the fields in $file are separated by spaces; separate them with tabs"
    exit 1
  fi
  first=$(printf '%s\n' "$got" | head -1)
  if [ "$first" != "$(printf '%s\n' "$want" | head -1)" ]; then
    if [ "$file" = inventory.tsv ] && [ "$first" = "$(printf 'hostname\tserial\track')" ]; then
      echo "❌ inventory.tsv starts with hostname, serial, rack: cut prints fields in file order, whatever order you give in -f"
    elif printf '%s\n' "$want" | sed -n '2p' | grep -qxF -- "$first"; then
      echo "❌ $file has no header line; keep the header of assets.tsv"
    else
      echo "❌ the first line of $file should be the header: $(printf '%s\n' "$want" | head -1 | sed 's/\t/<TAB>/g')"
    fi
    exit 1
  fi
  bad=$(printf '%s\n' "$got" | awk -F'\t' -v n="$nf" 'NF != n { print NR; exit }')
  if [ -n "$bad" ]; then
    echo "❌ line $bad of $file does not have $nf tab-separated fields ($what); were values with spaces split?"
    exit 1
  fi
  n=$(printf '%s\n' "$got" | wc -l | tr -d ' ')
  if [ "$n" -ne 401 ]; then
    echo "❌ $file has $n lines; assets.tsv has 401 (header + 400 rows)"
  else
    ln=$(diff <(printf '%s\n' "$got") <(printf '%s\n' "$want") | grep -m1 -o '^[0-9]*')
    echo "❌ line $ln of $file should be '$(printf '%s\n' "$want" | sed -n "${ln}p" | tr '\t' '|')' (| = tab), but is '$(printf '%s\n' "$got" | sed -n "${ln}p" | tr '\t' '|')'; did whitespace inside a value split a field?"
  fi
  exit 1
}

check inventory.tsv 3 "serial, hostname, rack" "$(awk -F'\t' -v OFS='\t' '{ print $5, $2, $9 }' assets.tsv)"
check vendor.tsv 13 "every column but owner_email" "$(awk -F'\t' '{ s = $1; for (i = 2; i <= NF; i++) if (i != 11) s = s "\t" $i; print s }' assets.tsv)"
echo "✅ inventory.tsv has serial, hostname, rack in that order and vendor.tsv has every column but owner_email"
exit 0
