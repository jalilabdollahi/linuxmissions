#!/bin/bash
# Source each host's os-release in a subshell (a symlink is followed by the
# shell, and quotes are handled), then look the release up in eol.csv.
for d in fleet/*/; do
  h=$(basename "$d")
  ( . "fleet/$h/etc/os-release"
    major=$VERSION_ID; [ "$ID" != ubuntu ] && major=${VERSION_ID%%.*}
    echo "$h $ID $VERSION_ID $major" )
done | while read -r h id v major; do
  e=$(awk -F, -v k="$id,$major" '$1 "," $2 == k { print $3 }' eol.csv)
  [ -n "$e" ] && [ "$e" \< "2026-11-11" ] && echo "$h $id $v"
done | sort > eol_hosts.txt
cat eol_hosts.txt
