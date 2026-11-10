#!/bin/bash
# Reference solution: compare the status column exactly, print columns 1 and 3.
awk -F, '$5 == "active" {print $1 "," $3}' users.csv > extract.csv
head -3 extract.csv
