#!/bin/bash
id=$(grep -o '[0-9a-fA-F]\{8\}-[0-9a-fA-F-]\{27\}' TICKET.txt | head -1)
pat="$id|${id//-/}|${id//-/%2D}"
zgrep -aihE "$pat" logs/* \
 | awk '{ if ($1 ~ /^20/) k=$1; else { split($4,a,"[/:]"); k=sprintf("2026-11-%sT%s:%s:%s",substr(a[1],2),a[4],a[5],a[6]) } print k "\t" $0 }' \
 | sort -s -t$'\t' -k1,1 | cut -f2- > trail.txt
