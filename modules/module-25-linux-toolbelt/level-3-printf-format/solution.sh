#!/bin/bash
# Skip the header, split each line on commas, let printf do the padding and cutting.
tail -n +2 accounts.csv | while IFS=, read -r id name amount; do
  printf 'ACCT%06d|%-12.12s|%10.2f\n' "$id" "$name" "$amount"
done > billing.dat
head -3 billing.dat
