#!/bin/bash
# Look at the columns first, then keep the accounts whose shell is in
# etc/shells and whose UID is a person's (1000-59999) or 0 (but not root).
cut -d: -f1,3,7 etc/passwd
awk -F: '$7 !~ /(nologin|false)$/ && (($3 >= 1000 && $3 <= 59999) || ($3 == "0" && $1 != "root")) { print $1 }' etc/passwd > humans.txt
cat humans.txt
