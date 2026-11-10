#!/bin/bash
P=$(cat dns.port)
rm -f fcrdns-fail.txt
for ip in $(cat senders.txt); do
  name=$(host -p "$P" "$ip" 127.0.0.1 | awk '/domain name pointer/ {print $NF}')
  if [ -n "$name" ] && host -p "$P" -t A "$name" 127.0.0.1 | awk -v ip="$ip" '$NF == ip {f = 1} END {exit !f}'; then
    echo "pass $ip $name"
  else
    echo "FAIL $ip ${name:-no PTR}"
    echo "$ip" >> fcrdns-fail.txt
  fi
done
touch fcrdns-fail.txt
