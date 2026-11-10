#!/bin/bash
# keep the header aside, split only the data rows, and let --filter put the
# header back in front of every chunk as it is written
mkdir -p chunks
head -n 1 customers.csv > header.txt
tail -n +2 customers.csv | split -l 5000 -d --additional-suffix=.csv \
  --filter='{ cat header.txt; cat; } > chunks/$FILE' - part-
wc -l chunks/*
