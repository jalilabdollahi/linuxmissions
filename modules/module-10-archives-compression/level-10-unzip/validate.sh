#!/bin/bash
# import/ = the existing customers.csv + the four other real CSVs from the zip,
# flat, nothing else.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/customers.sum ] || [ ! -s .lm-state/zip.sum ]; then
  echo "❌ the level's reference data in .lm-state/ is gone; type 'reset'"
  exit 1
fi
if [ ! -f upload.zip ] || [ "$(cksum < upload.zip)" != "$(cat .lm-state/zip.sum)" ]; then
  echo "❌ upload.zip is gone or was changed; type 'reset'"
  exit 1
fi
if [ ! -f import/customers.csv ]; then
  echo "❌ import/customers.csv is gone; type 'reset'"
  exit 1
fi
if [ "$(cksum < import/customers.csv)" != "$(cat .lm-state/customers.sum)" ]; then
  if unzip -p upload.zip export/customers.csv | cmp -s - import/customers.csv; then
    echo "❌ import/customers.csv was overwritten with the older copy from the zip; yesterday's corrections are lost (type 'reset')"
  else
    echo "❌ import/customers.csv was changed; it must stay as it was (type 'reset')"
  fi
  exit 1
fi

sub=$(cd import && find . -mindepth 1 -type d | head -1)
if [ -n "$sub" ]; then
  echo "❌ import/${sub#./} is a directory; the importer wants the CSVs directly in import/ (flatten the zip's paths)"
  exit 1
fi
mac=$(cd import && ls -A | grep -e '^\._' -e '^\.DS_Store$' | head -1)
if [ -n "$mac" ]; then
  echo "❌ import/$mac is Mac metadata from __MACOSX/, not a CSV; leave those out"
  exit 1
fi
extra=$(cd import && ls -A | grep -vxE '(customers|contacts|orders|invoices|refunds)\.csv' | head -1)
if [ -n "$extra" ]; then
  echo "❌ import/$extra is not a CSV the importer can read; only .csv files belong in import/"
  exit 1
fi
for pair in contacts.csv:contacts.csv orders.csv:export/orders.csv invoices.csv:export/2026/q3/invoices.csv refunds.csv:export/2026/q3/refunds.csv; do
  name=${pair%%:*}; member=${pair#*:}
  if [ ! -f "import/$name" ]; then
    echo "❌ import/$name is missing (the CSVs sit at different depths in the zip; unzip -l shows where)"
    exit 1
  fi
  if ! unzip -p upload.zip "$member" | cmp -s - "import/$name"; then
    echo "❌ import/$name differs from $member in the zip"
    exit 1
  fi
done
echo "✅ import/ holds the 4 CSVs from the zip plus your corrected customers.csv, flat and nothing else"
exit 0
