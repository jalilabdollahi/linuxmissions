#!/bin/bash
# Find the server block by its server_name, read the server-level directive.
grep -n 'server_name uploads.example.com' nginx-full.conf
start=$(grep -n 'server_name uploads.example.com' nginx-full.conf | cut -d: -f1)
sed -n "$start,$((start + 20))p" nginx-full.conf
sed -n "$start,$((start + 20))p" nginx-full.conf | grep -E '^ {8}client_max_body_size' | awk '{ gsub(";", "", $2); print $2 }' > answer.txt
cat answer.txt
