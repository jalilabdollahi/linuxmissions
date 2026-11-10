#!/bin/bash
# Print the range from the exact header to the next header, drop that last
# line; print a numbered line range and stop reading after it.
grep -n '^\[' app.ini
sed -n '/^\[database\]$/,/^\[/p' app.ini | sed '$d' > db-section.txt
sed -n '1200,1260p;1260q' trace.log > excerpt.txt
cat db-section.txt
wc -l excerpt.txt
