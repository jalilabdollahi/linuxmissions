#!/bin/bash
# Reference solution
{
  echo "requests=$(wc -l < access.log)"
  echo "unique_ips=$(awk '{print $1}' access.log | sort -u | wc -l)"
  echo "bytes=$(awk '{sum += $10} END {print sum}' access.log)"
} > report.txt
cat report.txt
