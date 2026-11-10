#!/bin/bash
# invoices.txt must list exactly the ten invoice PDFs under share/.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

EXPECTED="share/Finance/2026/Q1/Invoice_2026-01.PDF
share/Finance/2026/Q1/Invoice_2026-02.PDF
share/Finance/2026/Q1/Invoice_2026-03.PDF
share/Finance/2026/Q2/invoice - april.pdf
share/Finance/2026/Q2/invoice - may.pdf
share/Finance/archive/INVOICES_2025.PDF
share/Sales/Customers/Acme Corp/Acme invoice 2291.pdf
share/Sales/Customers/Bolt GmbH/Proforma-Invoice-BG-118.Pdf
share/Scans/2026-03-14/scan_invoice_0007.pdf
share/Scans/2026-03-14/.invoice_0008.pdf"

while IFS= read -r f; do
  if [ ! -f "$f" ]; then
    echo "❌ $f is gone from share/; type 'reset' to restore the drive"
    exit 1
  fi
done <<< "$EXPECTED"

if [ ! -f invoices.txt ]; then
  echo "❌ invoices.txt does not exist yet"
  exit 1
fi

# Accept share/x, ./share/x and absolute paths.
GOT=$(tr -d '\r' < invoices.txt | sed -e "s|^$SANDBOX/||" -e 's|^\./||' | grep -v '^[[:space:]]*$')
if [ -z "$GOT" ]; then
  echo "❌ invoices.txt is empty"
  exit 1
fi

dup=$(printf '%s\n' "$GOT" | sort | uniq -d | head -1)
if [ -n "$dup" ]; then
  echo "❌ invoices.txt lists $dup more than once"
  exit 1
fi

while IFS= read -r line; do
  if printf '%s\n' "$EXPECTED" | grep -qxF -- "$line"; then
    continue
  fi
  if [ "$line" = "request-invoice-copies.pdf" ]; then
    echo "❌ invoices.txt lists request-invoice-copies.pdf: that is Legal's letter, not a file under share/"
  elif [ -f "$line" ]; then
    echo "❌ invoices.txt lists $line, but its name does not both contain invoice and end in .pdf"
  else
    echo "❌ invoices.txt has a line that is not the path of a file under share/: $line"
  fi
  exit 1
done <<< "$GOT"

have=$(printf '%s\n' "$GOT" | wc -l | tr -d ' ')
if [ "$have" -lt 10 ]; then
  echo "❌ invoices.txt lists $have invoice PDF(s), but share/ holds more; check the letter case of names and extensions"
  exit 1
fi
echo "✅ invoices.txt lists all 10 invoice PDFs, whatever their case, spaces or hidden names"
exit 0
