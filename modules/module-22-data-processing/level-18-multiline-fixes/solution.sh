#!/bin/bash
# A record is complete when it has an even number of double quotes (an
# escaped "" adds two, so it never changes the parity). Glue the lines of a
# record together with a space until that is the case.
grep -c . tickets.csv
awk '{ q += gsub(/"/, "&"); rec = (part ? rec " " $0 : $0); part = 1 }
     q % 2 == 0 { print rec; q = 0; part = 0 }' tickets.csv > tickets_flat.csv
tail -n +2 tickets_flat.csv | wc -l | tr -d ' ' > count.txt
cat count.txt
