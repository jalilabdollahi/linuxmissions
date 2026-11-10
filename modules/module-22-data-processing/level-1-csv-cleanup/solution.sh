#!/bin/bash
# Drop the BOM from line 1, delete every CR, then drop the lines that are now empty.
sed '1s/^\xEF\xBB\xBF//' contacts.csv | tr -d '\r' | grep -v '^$' > contacts_clean.csv
head -3 contacts_clean.csv | cat -A
