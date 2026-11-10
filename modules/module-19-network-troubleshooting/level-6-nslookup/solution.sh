#!/bin/bash
P=$(cat dns.port)
while read -r name; do
  out=$(nslookup -port="$P" -timeout=2 -retry=1 "$name" 127.0.0.1 2>&1)
  case "$out" in
    *NXDOMAIN*)                      s=NXDOMAIN ;;
    *SERVFAIL*)                      s=SERVFAIL ;;
    *"no servers could be reached"*) s=TIMEOUT ;;
    *Name:*)                         s=OK ;;
    *)                               s=UNKNOWN ;;
  esac
  printf '%s\t%s\n' "$name" "$s"
done < names.txt > results.tsv
cat results.tsv
