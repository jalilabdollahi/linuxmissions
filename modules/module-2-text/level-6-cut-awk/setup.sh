#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

names=(alice bob carol dave eve frank grace heidi ivan judy mallory niaj olivia peggy rupert sybil trent victor walter yuki)
roles=(user user admin user billing user)
statuses=(active inactive active suspended active active inactive)

{
  echo "username,age,email,role,status"
  for i in $(seq 0 119); do
    u="${names[$(( i % 20 ))]}$(( i / 20 + 1 ))"
    domain=example.com; [ $(( i % 9 )) -eq 0 ] && domain=mail.example.org
    echo "$u,$(( 21 + (i * 7) % 44 )),$u@$domain,${roles[$(( i % 6 ))]},${statuses[$(( (i * 3) % 7 ))]}"
  done
} > users.csv
