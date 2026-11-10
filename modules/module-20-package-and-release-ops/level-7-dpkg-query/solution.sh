#!/bin/bash
Q="dpkg-query --admindir=prod/var/lib/dpkg -W"
$Q -f='${db:Status-Abbrev}|${Package}\n' | awk -F'|' '{s = substr($1, 2, 1)} s != "i" && s != "n" {print $2}' > broken.txt
$Q -f='${db:Status-Abbrev}|${Installed-Size}|${Section}\n' | awk -F'|' '$1 ~ /^[ih]i/ && $3 == "libs" {t += $2} END {printf "%d\n", t / 1024 + 0.5}' > libs-mib.txt
cat broken.txt libs-mib.txt
