#!/bin/bash
# $1 = sandbox path
# Asks each server for the corp.example SOA (dig) to know which one is
# stale, checks triage.env, checks that etc/resolv.conf can no longer reach
# the stale server, then runs the checkout smoke test (a pristine copy).
SANDBOX="$1"
cd "$SANDBOX" || exit 1

declare -A port serial ip
for ns in ns1 ns2 ns3; do
  port[$ns]=$(cat ".net/$ns.port")
  serial[$ns]=$(dig @127.0.0.1 -p "${port[$ns]}" corp.example SOA +short +time=2 +tries=2 | awk '{ print $3 }')
  [ -n "${serial[$ns]}" ] || { echo "❌ $ns does not answer; type 'reset' to restart the lab"; exit 1; }
done
ip[ns1]=10.53.1.11 ip[ns2]=10.53.1.12 ip[ns3]=10.53.1.13
for ns in ns2 ns3; do [ "${serial[$ns]}" != "${serial[ns1]}" ] && stale=$ns; done

[ -f triage.env ] || { echo "❌ triage.env does not exist yet"; exit 1; }
val() { sed -n "s/^[[:space:]]*\(export[[:space:]]*\)\{0,1\}$1[[:space:]]*=[[:space:]]*//p" triage.env | tail -1 | tr -d "\"'\r" | sed 's/[[:space:]]*$//'; }
s=$(val STALE) ss=$(val STALE_SERIAL) gs=$(val GOOD_SERIAL)
[ -n "$s" ] && [ -n "$ss" ] && [ -n "$gs" ] || { echo "❌ triage.env needs STALE=, STALE_SERIAL= and GOOD_SERIAL= lines"; exit 1; }
[ "$s" = "${ip[$stale]}" ] && s=$stale
if [ "$s" != "$stale" ]; then
  echo "❌ STALE=$s: that server's data matches the primary; compare the corp.example SOA serial of every server"; exit 1
fi
[ "$gs" = "${serial[ns1]}" ] || { echo "❌ GOOD_SERIAL is not the serial in the primary's (ns1) SOA record"; exit 1; }
[ "$ss" = "${serial[$stale]}" ] || { echo "❌ STALE_SERIAL is not the serial in $stale's SOA record"; exit 1; }

[ -f etc/resolv.conf ] || { echo "❌ etc/resolv.conf is missing"; exit 1; }
mapfile -t servers < <(awk '$1 == "nameserver" { print $2 }' etc/resolv.conf | head -3)
[ ${#servers[@]} -gt 0 ] || { echo "❌ etc/resolv.conf has no nameserver left"; exit 1; }
for a in "${servers[@]}"; do
  case $a in 10.53.1.11|10.53.1.12|10.53.1.13) ;; *) echo "❌ nameserver $a is not one of the corp.example servers in servers.txt"; exit 1 ;; esac
done
rotate=$(awk '$1 == "options"' etc/resolv.conf | grep -cw rotate)
for i in "${!servers[@]}"; do
  if [ "${servers[$i]}" = "${ip[$stale]}" ]; then
    if [ "$rotate" -gt 0 ]; then
      echo "❌ with 'rotate', $stale (${ip[$stale]}) still gets its share of the lookups"; exit 1
    elif [ "$i" -eq 0 ]; then
      echo "❌ $stale (${ip[$stale]}) is still the first nameserver, so it answers every lookup"; exit 1
    fi
  fi
done

out=$(python3 .net/smoke-dns.orig 2>&1)
if [ $? -ne 0 ]; then
  echo "❌ smoke-dns: $(echo "$out" | tail -1); $(echo "$out" | grep -m1 FAIL)"; exit 1
fi
echo "✅ $stale is stale (serial ${serial[$stale]} vs ${serial[ns1]}), and app-21 no longer asks it: smoke-dns 20/20"
