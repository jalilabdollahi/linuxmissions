#!/bin/bash
# Reference solution: match the method (with its opening quote), then count per IP.
grep '"POST ' access.log | awk '{print $1}' | sort | uniq -c | sort -rn > post_ips.txt
cat post_ips.txt
