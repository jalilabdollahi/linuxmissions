#!/bin/bash
# Keep the header on top; sort the rest on three bounded keys.
head -1 inventory.txt > sorted.txt
tail -n +2 inventory.txt | sort -k2,2 -k4,4gr -k1,1V >> sorted.txt
head -15 sorted.txt
