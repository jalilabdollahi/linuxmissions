#!/bin/bash
port=$(awk -F: '/^listen=/ {print $NF}' releases/ledger-api-2.0/ledger-api.conf)
ss -ltnp | grep ":$port "
pid=$(ss -Hltnp "sport = :$port" | grep -o 'pid=[0-9]*' | cut -d= -f2)
ps -ww -o pid,args -p "$pid"
kill "$pid"
while ss -Hltn "sport = :$port" | grep -q .; do sleep 0.1; done   # wait until the port is free
./releases/ledger-api-2.0/start.sh
