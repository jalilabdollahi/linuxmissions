#!/bin/bash
grep -B1 FATAL worker.log | head
# -w: req= must start a word, so parent_req=... is not taken.
grep -B1 FATAL worker.log | grep -o -w 'req=[0-9a-f]*' | cut -d= -f2 > fatal-reqs.txt
cat fatal-reqs.txt
