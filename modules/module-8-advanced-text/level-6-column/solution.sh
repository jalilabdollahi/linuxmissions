#!/bin/bash
# -t: make a table; -s ,: the input columns are separated by commas (not spaces).
column -t -s , services.csv > table.txt
cat table.txt
