#!/bin/bash
# -b a numbers all lines (blank ones too), -w3 is the number width, -s sets the separator.
nl -b a -w 3 -s ': ' nginx.conf > review.txt
sed -n '1,12p' review.txt
