#!/bin/bash
# Rewrite the row with printf and the original column widths; pass everything else through.
awk '$0 !~ /^#/ && NF == 5 && $5 == "B" { printf "%-12s %-15s %-5s %-7s %s\n", $1, $2, $3, 0, $5; next } { print }' upstreams.tab > upstreams.new
mv upstreams.new upstreams.tab
cat upstreams.tab
