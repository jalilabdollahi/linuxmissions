#!/bin/bash
# passwd says where homes should be; map /home/x onto ./home/x and compare.
cut -d: -f1,6 etc/passwd
ls -A home
awk -F: '$6 ~ /^\/home\// { print $1, $6 }' etc/passwd | while read -r u h; do
  [ -d ".$h" ] || echo "$u"
done > missing.txt
awk -F: '$6 ~ /^\/home\// { sub("^/home/", "", $6); print $6 }' etc/passwd | sort > /tmp/lm-expected-homes.$$
find home -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort | comm -23 - /tmp/lm-expected-homes.$$ > orphans.txt
rm -f /tmp/lm-expected-homes.$$
awk -F: '$6 ~ /^\/home\// { print $6 }' etc/passwd | while read -r h; do
  [ -d ".$h" ] && chmod 750 ".$h"
done
cat missing.txt orphans.txt
stat -c '%a %n' home/*
