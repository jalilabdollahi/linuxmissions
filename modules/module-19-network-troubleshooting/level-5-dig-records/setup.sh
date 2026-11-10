#!/bin/bash
# Local DNS server for shop.example. Three MX records in random order; the
# primary (lowest preference, a one-digit number so a text sort gets it wrong)
# points at a CNAME that points at another CNAME. Names, preferences and
# addresses change per setup.
SANDBOX="$1"
NET="$SANDBOX/.net"; mkdir -p "$NET"
MOCKS="$(cd "$(dirname "$0")/../../../mocks/net" && pwd)"
cp "$MOCKS/dns_server.py" "$NET/"

read -r n1 n2 n3 < <(shuf -i 1-9 -n 3 | tr '\n' ' ')   # host numbers, unrelated to priority
prim_pref=$((1 + RANDOM % 9))
back1_pref=$((10 + RANDOM % 5 * 10))
back2_pref=$((back1_pref + 10 + RANDOM % 3 * 10))
region=$(shuf -n1 -e eu-west eu-central us-east ap-south)
edge=$((1 + RANDOM % 9))
ip_prim="198.51.100.$((10 + RANDOM % 200))"
ip_b1="203.0.113.$((10 + RANDOM % 100))"
ip_b2="203.0.113.$((120 + RANDOM % 100))"

mx_lines=$(printf '%s\n' \
  "@            MX    $prim_pref mx$n1" \
  "@            MX    $back1_pref mx$n2" \
  "@            MX    $back2_pref mx$n3" | shuf)

cat > "$NET/zone.db" <<EOF
\$ORIGIN shop.example.
\$TTL 300
@            IN SOA ns1 hostmaster ( 2026111003 3600 600 86400 300 )
@            NS    ns1
ns1          A     127.0.0.1
@            A     203.0.113.$((RANDOM % 9 + 1))
www          CNAME shop.example.
$mx_lines
mx$n1        CNAME mx.mailrelay.example.
mx$n2        A     $ip_b1
mx$n3        A     $ip_b2
@            TXT   "v=spf1 mx include:mailrelay.example -all"

\$ORIGIN mailrelay.example.
@            IN SOA ns1 hostmaster ( 2026110901 3600 600 86400 300 )
@            NS    ns1
ns1          A     127.0.0.1
mx           CNAME $region.edge$edge
$region.edge$edge  60 A  $ip_prim
EOF
printf 'MX_HOST=mx%s.shop.example\nMX_IP=%s\n' "$n1" "$ip_prim" > "$NET/expected"
printf '%s\n' "mx$n2.shop.example" "mx$n3.shop.example" > "$NET/backups"

python3 "$NET/dns_server.py" --zone "$NET/zone.db" --log "$NET/query.log" \
    --port-file "$SANDBOX/dns.port" --daemon \
  || { echo "could not start the DNS server" >&2; exit 1; }

cat > "$SANDBOX/TICKET.txt" <<'EOF'
TICKET-3318  Mail to @shop.example bounces
------------------------------------------
Partners report bounces for everything sent to @shop.example. Before we
call the mail host, find out where mail for shop.example is supposed to
go first:

  MX_HOST  the primary mail exchanger of shop.example (the name in the MX record)
  MX_IP    the IPv4 address that name finally resolves to

The test DNS server with the production zone runs on 127.0.0.1; its port
is in dns.port. Write both values to mx.env.
EOF
