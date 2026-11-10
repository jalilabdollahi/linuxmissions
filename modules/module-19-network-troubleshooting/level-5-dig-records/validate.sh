#!/bin/bash
SANDBOX="$1"
NET="$SANDBOX/.net"
OUT="$SANDBOX/mx.env"

if [ ! -f "$OUT" ]; then
  echo "❌ mx.env does not exist yet"
  exit 1
fi
if ! grep -q ' shop\.example\. MX ' "$NET/query.log" 2>/dev/null; then
  echo "❌ the DNS server has not been asked for the MX records of shop.example yet"
  exit 1
fi

val() { grep -E "^[[:space:]]*$1=" "$2" | tail -n 1 | cut -d= -f2- | tr -d "\"' \r" ; }
want_host=$(val MX_HOST "$NET/expected")
want_ip=$(val MX_IP "$NET/expected")
host=$(val MX_HOST "$OUT" | tr 'A-Z' 'a-z'); host=${host%.}
ip=$(val MX_IP "$OUT")

if [ -z "$host" ] || [ -z "$ip" ]; then
  echo "❌ mx.env needs both MX_HOST= and MX_IP= lines"
  exit 1
fi
if [ "$host" != "$want_host" ]; then
  if grep -qx "$host" "$NET/backups"; then
    echo "❌ MX_HOST $host is a backup: the MX with the LOWEST preference number is tried first (compare them as numbers)"
  elif [[ "$host" == *mailrelay.example ]]; then
    echo "❌ MX_HOST should be the name written in the MX record, not where it points to"
  else
    echo "❌ MX_HOST $host is not one of the mail exchangers of shop.example"
  fi
  exit 1
fi
if [ "$ip" != "$want_ip" ]; then
  if ! grep -q "^.* $want_host\. A " "$NET/query.log"; then
    echo "❌ MX_IP is wrong, and nobody has looked up the A record of $host yet"
  else
    echo "❌ MX_IP $ip is not where $host finally resolves to (follow every CNAME to the A record)"
  fi
  exit 1
fi
echo "✅ primary MX $want_host resolves (through two CNAMEs) to $want_ip"
