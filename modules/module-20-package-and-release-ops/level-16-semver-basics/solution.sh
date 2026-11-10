#!/bin/bash
IFS=. read -r M m p < VERSION
if grep -qE '^[0-9a-f]+ [a-z]+(\([^)]*\))?!: |^BREAKING[ -]CHANGE: ' commits.txt; then
  new="$((M + 1)).0.0"
elif grep -qE '^[0-9a-f]+ feat(\([^)]*\))?: ' commits.txt; then
  new="$M.$((m + 1)).0"
else
  new="$M.$m.$((p + 1))"
fi
echo "$new" > VERSION
sed -i "s/\"version\": \"[^\"]*\"/\"version\": \"$new\"/" package.json
grep -E '^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$' all-tags.txt | sed 's/-/~/' | LC_ALL=C sort -V | sed 's/~/-/' | tail -n 10 > tags.txt
