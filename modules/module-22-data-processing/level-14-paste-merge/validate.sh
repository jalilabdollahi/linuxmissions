#!/bin/bash
# parcels.tsv = header + one tab-separated row per 4-line block of
# scan_dump.txt (no "--", no CR); manifest.txt = all parcel ids on one line,
# comma-separated, in dump order.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/dump.sum ] || [ "$(cksum < scan_dump.txt 2>/dev/null)" != "$(cat .lm-state/dump.sum)" ]; then
  echo "❌ scan_dump.txt was changed or removed; type 'reset' to restore it"
  exit 1
fi
for f in parcels.tsv manifest.txt; do
  if [ ! -f "$f" ]; then
    echo "❌ $f does not exist yet"
    exit 1
  fi
done

ROWS=$(awk '{ sub(/\r$/, "") } $0 != "--" { v[++k] = $0; if (k == 4) { printf "%s\t%s\t%s\t%s\n", v[1], v[2], v[3], v[4]; k = 0 } }' scan_dump.txt)
NP=$(printf '%s\n' "$ROWS" | wc -l | tr -d ' ')

if grep -q $'\r' parcels.tsv; then
  echo "❌ parcels.tsv contains carriage returns (\\r): some batches of the dump have Windows line endings, and they end up inside the rows"
  exit 1
fi
if [ "$(head -n 1 parcels.tsv)" != "$(printf 'parcel\tweight_kg\tpostcode\tdock')" ]; then
  echo "❌ the first line of parcels.tsv must be the header parcel, weight_kg, postcode, dock separated by tabs"
  exit 1
fi
BODY=$(tail -n +2 parcels.tsv)
if [ "$BODY" != "$ROWS" ]; then
  if grep -qx -- '--' parcels.tsv || grep -q $'\t--$\|^--\t\|\t--\t' parcels.tsv; then
    echo "❌ parcels.tsv contains the -- separator lines as values, so the rows are shifted; remove them before joining the lines"
  elif awk -F'\t' 'NR > 1 && NF != 4 { f = 1 } END { exit !f }' parcels.tsv; then
    echo "❌ every row of parcels.tsv must have 4 tab-separated fields: parcel, weight_kg, postcode, dock"
  elif [ "$(printf '%s\n' "$BODY" | wc -l | tr -d ' ')" -ne "$NP" ]; then
    echo "❌ parcels.tsv has $(printf '%s\n' "$BODY" | wc -l | tr -d ' ') data rows, but the dump has $NP parcels"
  else
    l=$(diff <(printf '%s\n' "$ROWS") <(printf '%s\n' "$BODY") | grep -m1 '^[0-9]' | sed 's/[^0-9].*//')
    echo "❌ row $l of parcels.tsv is not the parcel at that position in the dump"
  fi
  exit 1
fi

WANT_M=$(printf '%s\n' "$ROWS" | cut -f1 | paste -sd, -)
if grep -q $'\r' manifest.txt; then
  echo "❌ manifest.txt contains carriage returns (\\r)"
  exit 1
fi
if [ "$(grep -c '' manifest.txt)" -ne 1 ]; then
  echo "❌ manifest.txt must be one single line, it has $(grep -c '' manifest.txt)"
  exit 1
fi
GOT_M=$(cat manifest.txt)
if [ "$GOT_M" != "$WANT_M" ]; then
  if [ "${GOT_M%,}" != "$GOT_M" ] || [ "${GOT_M#,}" != "$GOT_M" ]; then
    echo "❌ manifest.txt starts or ends with a comma; commas go only between the ids"
  elif [ "$(printf '%s' "$GOT_M" | tr ',' '\n' | grep -c .)" -ne "$NP" ]; then
    echo "❌ manifest.txt lists $(printf '%s' "$GOT_M" | tr ',' '\n' | grep -c .) ids, but the dump has $NP parcels"
  else
    echo "❌ manifest.txt must hold the parcel ids (only the ids) in dump order, separated by commas"
  fi
  exit 1
fi
echo "✅ parcels.tsv has all $NP parcels on one row each, and manifest.txt lists them for the carrier"
