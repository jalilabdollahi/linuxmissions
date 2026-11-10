#!/bin/bash
# Aggregate the orders per customer, then left-join the customer list on the
# id (both sides sorted as text, in the C locale), fill the gaps and sort the
# result by id as a number.
head -3 customers.csv orders.csv
export LC_ALL=C
tail -n +2 orders.csv | awk -F, '{ n[$4]++; s[$4] += $3 } END { for (c in n) printf "%s,%d,%.2f\n", c, n[c], s[c] }' | sort -t, -k1,1 > orders.agg
tail -n +2 customers.csv | sort -t, -k1,1 > customers.sorted
{
  echo customer_id,name,orders,total
  join -t, -a1 -e NONE -o 1.1,1.2,2.2,2.3 customers.sorted orders.agg \
    | sed 's/,NONE,NONE$/,0,0.00/' | sort -t, -k1,1n
} > customer_totals.csv
rm orders.agg customers.sorted
head customer_totals.csv
