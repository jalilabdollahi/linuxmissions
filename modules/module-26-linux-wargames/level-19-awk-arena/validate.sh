#!/bin/bash
SB="$1"; cd "$SB" || exit 1
if [ ! -s mismatch.csv ]; then echo "❌ mismatch.csv is missing or empty"; exit 1; fi
tr -d '\r' < mismatch.csv > .lm/got.csv
if [ "$(head -1 .lm/got.csv)" != "invoice,invoice_eur,provider_eur" ]; then echo "❌ the first line of mismatch.csv must be the header invoice,invoice_eur,provider_eur"; exit 1; fi
exp=$(($(wc -l < .lm/mismatch.csv) - 1)); got=$(($(wc -l < .lm/got.csv) - 1))
if [ "$(tail -n +2 .lm/got.csv | cut -d, -f1 | sort | uniq -d | wc -l)" -gt 0 ]; then echo "❌ an invoice is listed twice"; exit 1; fi
ids_missing=$(comm -13 <(tail -n +2 .lm/got.csv | cut -d, -f1 | sort) <(tail -n +2 .lm/mismatch.csv | cut -d, -f1 | sort) | wc -l)
ids_extra=$(comm -23 <(tail -n +2 .lm/got.csv | cut -d, -f1 | sort) <(tail -n +2 .lm/mismatch.csv | cut -d, -f1 | sort) | wc -l)
if [ "$ids_missing" -gt 0 ] || [ "$ids_extra" -gt 0 ]; then
  echo "❌ the list of invoices is wrong: $ids_missing mismatching invoice(s) missing, $ids_extra listed that match the provider (check which rate each invoice uses, and the units)"; exit 1; fi
if ! cmp -s .lm/got.csv .lm/mismatch.csv; then echo "❌ the right invoices are listed but amounts, decimals or sort order differ (two decimals, EUR, sorted by id)"; exit 1; fi
echo "✅ mismatch.csv lists exactly the $exp invoices that disagree with the provider"
