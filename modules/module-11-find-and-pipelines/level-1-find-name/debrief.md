# Invoices for Legal

## Why it works
`-iname` compares the pattern with each file *name* and ignores letter case, so
`'*invoice*.pdf'` matches `Invoice_2026-01.PDF`, `Proforma-Invoice-BG-118.Pdf` and
the hidden `.invoice_0008.pdf` the scanner left behind. find walks every folder and
hands names with spaces through untouched. The pattern must match the whole name,
which is why `invoices.pdf.bak` and `invoice BG-118.pdf.zip` stay out.

## Common mistakes
- `find share -iname *invoice*.pdf` without quotes: the shell expands the pattern
  first. Here it became `request-invoice-copies.pdf`, and find found nothing. With
  two matching files in the current folder, find fails with "paths must precede
  expression".
- `-name '*invoice*'` misses `Invoice_...` and `INVOICES_...`; `'*.pdf'` misses `.PDF`.
- `ls -R | grep -i invoice` loses the folder of each file and also lists the decoys.

## Learn next
`-ipath '*finance*invoice*'` matches against the whole path instead of the name,
and `-not -path '*/archive/*'` excludes a subtree. On a large tree, `locate -i`
searches a prebuilt index much faster than find.
