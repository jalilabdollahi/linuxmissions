#!/bin/bash
{
  grep -rnE 'AKIA[0-9A-Z]{16}' repo | grep -v AKIAIOSFODNN7EXAMPLE | cut -d: -f1,2
  grep -rnE -- '-----BEGIN .*PRIVATE KEY' repo | cut -d: -f1,2
  grep -rniE '^[[:space:]]*password[[:space:]]*=[[:space:]]*[^<$[:space:]]' repo | cut -d: -f1,2
  grep -rnE 'ghp_[A-Za-z0-9]{36}' repo | cut -d: -f1,2
  find repo -name '*.gz' -exec zgrep -nHE 'ghp_[A-Za-z0-9]{36}' {} + | cut -d: -f1,2
} | sort -u > leaks.txt
cat leaks.txt
