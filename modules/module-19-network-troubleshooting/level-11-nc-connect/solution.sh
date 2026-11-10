#!/bin/bash
rm -f open.txt
for p in $(grep -o '127\.0\.0\.1:[0-9]*' backends.txt | cut -d: -f2); do
  nc -z -w2 127.0.0.1 "$p" && echo "$p" >> open.txt
done
port=$(awk '$1 == "status" {print $2}' backends.txt | cut -d: -f2)
printf 'STATUS\n' | nc -q1 -w3 127.0.0.1 "$port" | grep -o 'token=[^ ]*' | cut -d= -f2 > token.txt
cat open.txt token.txt
