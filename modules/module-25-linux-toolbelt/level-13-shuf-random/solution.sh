#!/bin/bash
# drop the header, then draw 25 lines using seed.bin as the random source
tail -n +2 tx.csv | shuf -n 25 --random-source=seed.bin > sample.csv
wc -l sample.csv
