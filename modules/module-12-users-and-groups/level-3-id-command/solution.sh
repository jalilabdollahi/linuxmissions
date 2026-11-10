#!/bin/bash
# Files with no group named exactly www-data, whether it is gid= or in groups=.
cat id-*.txt
grep -L -E '[=,][0-9]+\(www-data\)' id-*.txt | sed -e 's/^id-//' -e 's/\.txt$//' > missing.txt
echo "$(id -u) $(id -g)" > me.txt
cat missing.txt me.txt
