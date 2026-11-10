#!/bin/bash
# General-numeric sort (understands e-notation) on column 3, reversed, top 10.
tail -n +2 readings.csv | sort -t, -k3,3gr | head -n 10 > top10.txt
cat top10.txt
