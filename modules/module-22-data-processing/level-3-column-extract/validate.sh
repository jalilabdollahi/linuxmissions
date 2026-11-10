#!/bin/bash
# emails.txt = the "email" column of old_export.csv, then of new_export.csv.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/exports.sum ] || [ "$(cat old_export.csv new_export.csv 2>/dev/null | cksum)" != "$(cat .lm-state/exports.sum)" ]; then
  echo "❌ old_export.csv or new_export.csv was changed or removed; type 'reset' to restore them"
  exit 1
fi
if [ ! -f emails.txt ]; then
  echo "❌ emails.txt does not exist yet"
  exit 1
fi

# Find the column by its exact header name in each file.
column_of() {
  awk -F, 'NR == 1 { for (i = 1; i <= NF; i++) if ($i == "email") c = i; next } { print $c }' "$1"
}
OLD=$(column_of old_export.csv)
NEW=$(column_of new_export.csv)
EXPECTED=$(printf '%s\n%s' "$OLD" "$NEW")
GOT=$(tr -d '\r' < emails.txt | sed '/^[[:space:]]*$/d')
if [ "$GOT" = "$EXPECTED" ]; then
  echo "✅ emails.txt: all $(printf '%s\n' "$EXPECTED" | wc -l | tr -d ' ') addresses, old export first, then the new one"
  exit 0
fi

if [ -z "$GOT" ]; then echo "❌ emails.txt is empty"; exit 1; fi
if printf '%s\n' "$GOT" | grep -qix 'email\|email_verified'; then
  echo "❌ emails.txt contains a header word; only the addresses from the data rows belong in it"
  exit 1
fi
if printf '%s\n' "$GOT" | grep -qx 'true\|false'; then
  echo "❌ emails.txt contains true/false values: that is the email_verified column, not the column named exactly email"
  exit 1
fi
if printf '%s\n' "$GOT" | grep -q ','; then
  echo "❌ some lines of emails.txt still contain commas; keep only the email field"
  exit 1
fi
bad=$(printf '%s\n' "$GOT" | grep -vc '@')
if [ "$bad" -gt 0 ]; then
  echo "❌ $bad line(s) of emails.txt are not e-mail addresses; check which column number email is in each file (it is not the same)"
  exit 1
fi
want=$(printf '%s\n' "$EXPECTED" | wc -l | tr -d ' ')
got=$(printf '%s\n' "$GOT" | wc -l | tr -d ' ')
if [ "$got" -ne "$want" ]; then
  echo "❌ emails.txt has $got addresses, expected $want (every data row of both files)"
  exit 1
fi
if [ "$GOT" = "$(printf '%s\n%s' "$NEW" "$OLD")" ]; then
  echo "❌ the addresses are right but in the wrong order: old_export.csv's rows first, then new_export.csv's"
  exit 1
fi
echo "❌ emails.txt has the right number of addresses, but some differ or are out of order; copy the values unchanged, in file order"
exit 1
