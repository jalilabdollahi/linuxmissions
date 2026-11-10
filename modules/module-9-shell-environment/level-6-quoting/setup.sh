#!/bin/bash
# Awkward Names: spaces, parentheses, a $ and an apostrophe in file names,
# next to decoys named like the pieces a wrongly quoted command would hit.
SANDBOX="$1"
mkdir -p "$SANDBOX/uploads" "$SANDBOX/archive"
cd "$SANDBOX/uploads" || exit 1

body() { printf 'portal upload: %s\nsize-class: %s\n' "$1" "$2"; }

body 'Q3 report (final).pdf' A > 'Q3 report (final).pdf'
body 'price$list.csv' B        > 'price$list.csv'
body "it's done.txt" C         > "it's done.txt"
# decoys
body 'Q3' D          > 'Q3'
body 'report' E      > 'report'
body '(final).pdf' F > '(final).pdf'
body 'price.csv' G   > 'price.csv'
body 'its done.txt' H > 'its done.txt'
body 'list.csv' I    > 'list.csv'
body 'Q3 report (draft).pdf' J > 'Q3 report (draft).pdf'
