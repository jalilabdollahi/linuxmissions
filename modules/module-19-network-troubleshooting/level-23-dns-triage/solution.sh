#!/bin/bash
# Compare SOA serials, confirm the difference on a changed name, then keep
# only the healthy servers in resolv.conf.
PATH="$PWD/bin:$PATH"
smoke-dns | tail -3
for ns in ns1 ns2 ns3; do
  p=$(awk -v n="$ns" '$1 == n { print $4 }' servers.txt)
  echo "$ns $(dig @127.0.0.1 -p "$p" corp.example SOA +short | awk '{ print $3 }') $(dig @127.0.0.1 -p "$p" pay-v2.corp.example +short)"
done > serials.txt
cat serials.txt
good=$(awk '$1 == "ns1" { print $2 }' serials.txt)
stale=$(awk -v g="$good" '$2 != g { print $1 }' serials.txt)
printf 'STALE=%s\nSTALE_SERIAL=%s\nGOOD_SERIAL=%s\n' "$stale" "$(awk -v s="$stale" '$1 == s { print $2 }' serials.txt)" "$good" > triage.env
stale_ip=$(awk -v s="$stale" '$1 == s { print $2 }' servers.txt)
grep -v "^nameserver $stale_ip" etc/resolv.conf > resolv.new && mv resolv.new etc/resolv.conf
smoke-dns | tail -1
