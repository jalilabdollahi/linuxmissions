#!/bin/bash
# Invoices for Legal: ten invoice PDFs with mixed-case names and extensions,
# spaces in names and folders, decoys that are almost invoice PDFs, and a
# request-invoice-copies.pdf in the sandbox root that an unquoted
# *invoice*.pdf pattern expands to before find ever sees it.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

mkdir -p share/Finance/2026/Q1 share/Finance/2026/Q2 share/Finance/templates \
         share/Finance/archive "share/Sales/Customers/Acme Corp" \
         "share/Sales/Customers/Bolt GmbH" share/Scans/2026-03-14 \
         share/HR/policies share/HR/onboarding share/IT/manuals share/Marketing/2025

doc() { printf '%s\n' "$2" > "$1"; }

# The ten invoice PDFs.
doc share/Finance/2026/Q1/Invoice_2026-01.PDF            '%PDF-1.4 invoice 2026-01'
doc share/Finance/2026/Q1/Invoice_2026-02.PDF            '%PDF-1.4 invoice 2026-02'
doc share/Finance/2026/Q1/Invoice_2026-03.PDF            '%PDF-1.4 invoice 2026-03'
doc "share/Finance/2026/Q2/invoice - april.pdf"          '%PDF-1.4 invoice april'
doc "share/Finance/2026/Q2/invoice - may.pdf"            '%PDF-1.4 invoice may'
doc share/Finance/archive/INVOICES_2025.PDF              '%PDF-1.4 all invoices of 2025'
doc "share/Sales/Customers/Acme Corp/Acme invoice 2291.pdf"          '%PDF-1.4 acme 2291'
doc "share/Sales/Customers/Bolt GmbH/Proforma-Invoice-BG-118.Pdf"    '%PDF-1.4 bolt 118'
doc share/Scans/2026-03-14/scan_invoice_0007.pdf         '%PDF-1.4 scanned invoice'
doc share/Scans/2026-03-14/.invoice_0008.pdf             '%PDF-1.4 scanned invoice, hidden by the scanner'

# Decoys: almost, but not, invoice PDFs.
doc share/Finance/templates/invoice-template.docx        'PK template'
doc share/Finance/templates/Invoice-Template.dotx        'PK template'
doc share/Finance/archive/invoices.pdf.bak               '%PDF-1.4 backup'
doc share/Finance/2026/Q1/invoice-numbers.xlsx           'PK numbers'
doc share/Finance/2026/Q2/Receipt_2026-05.pdf            '%PDF-1.4 receipt'
doc "share/Sales/Customers/Bolt GmbH/invoice BG-118.pdf.zip" 'PK zipped'
doc share/Sales/invoice.pdf.txt                          'Remember to attach the PDF'
doc share/HR/policies/invoicing-guideline.md             '# How we invoice'

# Filler: ordinary documents everywhere.
i=0
for d in share/HR/policies share/HR/onboarding share/IT/manuals share/Marketing/2025 \
         share/Finance/2026/Q1 share/Finance/2026/Q2 "share/Sales/Customers/Acme Corp" \
         "share/Sales/Customers/Bolt GmbH" share/Scans/2026-03-14; do
  for kind in report minutes "meeting notes" budget contract offer photo scan; do
    i=$((i + 1))
    for ext in pdf docx PDF jpg; do
      [ $(( (i + ${#ext}) % 3 )) -eq 0 ] && continue
      doc "$d/$kind $i.$ext" "$kind $i"
    done
  done
done

# Legal's request letter, outside share/.
doc request-invoice-copies.pdf '%PDF-1.4 Please send copies of every invoice on the old share.'
