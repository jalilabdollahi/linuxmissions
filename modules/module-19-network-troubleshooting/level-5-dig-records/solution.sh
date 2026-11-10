#!/bin/bash
P=$(cat dns.port)
mx=$(dig @127.0.0.1 -p "$P" shop.example MX +short | sort -n | head -n 1 | awk '{print $2}')
ip=$(dig @127.0.0.1 -p "$P" "$mx" A +short | tail -n 1)
printf 'MX_HOST=%s\nMX_IP=%s\n' "${mx%.}" "$ip" > mx.env
cat mx.env
