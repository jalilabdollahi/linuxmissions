#!/bin/bash
# Header from the first file, then every line after the first of each file.
# awk ends every printed record with a newline, even feb.csv's last one.
head -n 1 jan.csv > q1.csv
awk 'FNR > 1' jan.csv feb.csv mar.csv >> q1.csv
grep -c INV- q1.csv
