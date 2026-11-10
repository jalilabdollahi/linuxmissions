#!/bin/bash
# -iname matches the name case-insensitively; the quotes keep the shell from
# expanding the pattern against request-invoice-copies.pdf in the current folder.
find share -type f -iname '*invoice*.pdf'
find share -type f -iname '*invoice*.pdf' > invoices.txt
