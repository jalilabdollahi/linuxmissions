#!/bin/bash
u=$(cat url.txt)
final=$(curl -s -L -o /dev/null -w '%{url_effective}' "$u")
n=$(curl -s -L -o /dev/null -w '%{num_redirects}' "$u")
hdr=$(curl -s -D - -o /dev/null "$final" | tr -d '\r')
age=$(echo "$hdr" | grep -i '^cache-control:' | grep -o 'max-age=[0-9]*' | cut -d= -f2)
etag=$(echo "$hdr" | grep -i '^etag:' | cut -d' ' -f2-)
printf 'FINAL_URL=%s\nREDIRECTS=%s\nMAX_AGE=%s\nETAG=%s\n' "$final" "$n" "$age" "$etag" > headers.env
cat headers.env
