#!/bin/bash
# LISTEN rows only; skip loopback binds; port = text after the last colon.
awk '$1 == "LISTEN" && $4 !~ /^(127\.|\[::1\])/ { n = split($4, a, ":"); print a[n] }' ss-output.txt \
  | sort -nu > exposed.txt
cat exposed.txt
