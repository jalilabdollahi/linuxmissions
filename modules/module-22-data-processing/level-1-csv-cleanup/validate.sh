#!/bin/bash
# contacts_clean.csv must be contacts.csv without the UTF-8 BOM, without any
# CR byte and without empty lines, byte for byte, ending in a newline.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
export LC_ALL=C
CR=$(printf '\r')

if [ ! -s .lm-state/contacts.sum ] || [ "$(cksum < contacts.csv 2>/dev/null)" != "$(cat .lm-state/contacts.sum)" ]; then
  echo "❌ contacts.csv was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f contacts_clean.csv ]; then
  echo "❌ contacts_clean.csv does not exist yet"
  exit 1
fi

# The source always starts with the 3-byte BOM, so skipping 3 bytes removes it.
want_sum=$(tail -c +4 contacts.csv | tr -d '\r' | grep -v '^$' | cksum)
if [ "$(cksum < contacts_clean.csv)" = "$want_sum" ]; then
  rows=$(($(wc -l < contacts_clean.csv) - 1))
  echo "✅ contacts_clean.csv: clean header and all $rows contacts, LF endings, no blank rows"
  exit 0
fi

if [ ! -s contacts_clean.csv ]; then
  echo "❌ contacts_clean.csv is empty"
  exit 1
fi
if [ "$(head -c 3 contacts_clean.csv | od -An -tx1 | tr -d ' \n')" = "efbbbf" ]; then
  echo "❌ contacts_clean.csv still starts with the UTF-8 byte-order mark (bytes ef bb bf) in front of first_name; look at the first line with od -c or cat -A"
  exit 1
fi
if [ "$(head -n 1 contacts_clean.csv | tr -d '\r')" != "first_name,last_name,email,phone,company,city" ]; then
  echo "❌ the first line of contacts_clean.csv is not exactly the header first_name,last_name,email,phone,company,city"
  exit 1
fi
crs=$(grep -c "$CR" contacts_clean.csv)
if [ "$crs" -gt 0 ]; then
  echo "❌ $crs line(s) of contacts_clean.csv still end in a carriage return (^M in cat -A)"
  exit 1
fi
if grep -q '^$' contacts_clean.csv; then
  echo "❌ contacts_clean.csv still has $(grep -c '^$' contacts_clean.csv) empty line(s)"
  exit 1
fi
want_rows=$(tail -c +4 contacts.csv | tr -d '\r' | grep -vc '^$')
got_rows=$(wc -l < contacts_clean.csv | tr -d ' ')
if [ -n "$(tail -c 1 contacts_clean.csv)" ]; then
  echo "❌ the last line of contacts_clean.csv has no newline at the end"
  exit 1
fi
if [ "$got_rows" -ne "$want_rows" ]; then
  echo "❌ contacts_clean.csv has $got_rows lines, expected $want_rows (the header plus every contact row)"
  exit 1
fi
echo "❌ contacts_clean.csv has the right number of lines, but some rows differ from contacts.csv or are in another order; only the BOM, the CRs and the empty lines may change"
exit 1
