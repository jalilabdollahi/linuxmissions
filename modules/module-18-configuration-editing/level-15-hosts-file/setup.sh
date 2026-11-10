#!/bin/bash
# etc/hosts with: exact duplicate lines, one IP spread over several lines, two 10.9.* legacy
# hosts, and one name (cache.corp) on two different IPs (the first line is the one that
# resolves). The expected name -> IP map is written to .lm-state/expected.map.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p etc .lm-state

o() { echo $((RANDOM % 200 + 20)); }          # random last octet
A=$(o); B=$(o); C=$(o); D=$(o); E=$(o)
while [ "$B" = "$A" ]; do B=$(o); done
while [ "$C" = "$A" ] || [ "$C" = "$B" ]; do C=$(o); done
while [ "$D" = "$A" ] || [ "$D" = "$B" ] || [ "$D" = "$C" ]; do D=$(o); done
while [ "$E" = "$A" ] || [ "$E" = "$B" ] || [ "$E" = "$C" ] || [ "$E" = "$D" ]; do E=$(o); done

cat > etc/hosts <<HOSTS
# /etc/hosts - shared by the build fleet, see wiki/DNS-MIGRATION
127.0.0.1 localhost
::1 ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff02::1 ip6-allnodes

# core
10.1.0.$A gw.corp gw
10.1.0.$B db1.corp db1
10.1.0.$C app1.corp app1
10.1.0.$B db1-primary
10.1.0.$C app1.corp app1
10.1.0.$A gw

# caches (cache.corp moved in March, the old line was never removed)
10.1.0.$D cache.corp cache
10.1.0.$E cache.corp cache-old
10.1.0.$B db1

# decommissioned, delete after the migration
10.9.0.5 legacy-ldap.corp ldap0
10.9.0.6 old-mail.corp
HOSTS
cp etc/hosts .lm-state/original.hosts

cat > .lm-state/expected.map <<MAP
localhost 127.0.0.1
ip6-localhost ::1
ip6-loopback ::1
ip6-localnet fe00::0
ip6-allnodes ff02::1
gw.corp 10.1.0.$A
gw 10.1.0.$A
db1.corp 10.1.0.$B
db1 10.1.0.$B
db1-primary 10.1.0.$B
app1.corp 10.1.0.$C
app1 10.1.0.$C
cache.corp 10.1.0.$D
cache 10.1.0.$D
cache-old 10.1.0.$E
MAP
