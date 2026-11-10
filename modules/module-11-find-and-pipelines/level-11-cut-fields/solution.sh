#!/bin/bash
head -1 assets.tsv
# cut can't reorder fields, so awk with tab as input and output separator.
awk -F'\t' -v OFS='\t' '{ print $5, $2, $9 }' assets.tsv > inventory.tsv
# Every field except 11 (owner_email); portable form of cut --complement -f11.
cut -f1-10,12- assets.tsv > vendor.tsv
head -3 inventory.tsv vendor.tsv
