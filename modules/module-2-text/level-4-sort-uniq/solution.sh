#!/bin/bash
# Reference solution: the classic frequency pipeline.
awk '{print $1}' access.log | sort | uniq -c | sort -rn > top_ips.txt
head -5 top_ips.txt
