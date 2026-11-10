#!/bin/bash
du -k -d2 var | awk '$2 ~ /^var\/[^\/]+\/[^\/]+$/' | sort -rn | head -5 > top5.txt
