#!/bin/bash
# Look up api once and read the query logs: the server that drops every
# query is dead, and the NOERROR line shows the domain where api lives.
# Then: live server only, that domain first in the search list, default ndots.
PATH="$PWD/bin:$PATH"
getent hosts api
dead=$(grep -l DROPPED logs/dns-*.log | sed 's/.*dns-//; s/\.log$//')
live=$(grep '^nameserver' etc/resolv.conf | awk '{ print $2 }' | grep -vxF "$dead")
domain=$(awk '$6 == "NOERROR" && $4 ~ /^api\./ { sub(/^api\./, "", $4); sub(/\.$/, "", $4); print $4 }' "logs/dns-$live.log" | head -1)
others=$(sed -n 's/^search //p' etc/resolv.conf | tr ' ' '\n' | grep -vxF "$domain" | tr '\n' ' ')
cat > etc/resolv.conf <<EOT
search $domain $others
nameserver $live
options timeout:2 attempts:2
EOT
cat etc/resolv.conf
time getent hosts api
