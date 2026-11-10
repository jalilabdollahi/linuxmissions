#!/bin/bash
# Look up the position of "email" in each header, then cut that column.
head -1 old_export.csv | tr , '\n' | grep -nx email
head -1 new_export.csv | tr , '\n' | grep -nx email
tail -n +2 old_export.csv | cut -d, -f3 > emails.txt
tail -n +2 new_export.csv | cut -d, -f5 >> emails.txt
wc -l emails.txt
