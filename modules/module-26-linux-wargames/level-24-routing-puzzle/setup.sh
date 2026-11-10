#!/bin/bash
# Wargame 24: policy routing puzzle on a simulated `ip` (level-local helper).
# Faults: backup table lacks the DC routes (/16 and the storage /24), dc table
# lacks the storage /24, a stale high-priority rule for one host, and a metric
# tie between two default routes in main.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
rm -rf bin net PLAN.md .lm
mkdir -p bin net .lm
cp "$(dirname "$0")/ip" bin/ip; chmod 755 bin/ip
cat > net/rt_tables <<'T'
# reserved values
255 local
254 main
253 default
0   unspec
# local
100 backup
200 dc
T
cat > net/rules <<'T'
0:	from all lookup local
50:	from 10.9.0.5 to 10.20.0.0/16 lookup main
100:	from 10.9.0.0/24 lookup backup
200:	to 10.20.0.0/16 lookup dc
32766:	from all lookup main
32767:	from all lookup default
T
# swap which default is listed first so the tie is not resolved by luck
if [ $((RANDOM % 2)) -eq 0 ]; then
  d1="default via 10.20.255.1 dev eth1 metric 100"; d2="default via 203.0.113.1 dev eth0 metric 100"
else
  d2="default via 10.20.255.1 dev eth1 metric 100"; d1="default via 203.0.113.1 dev eth0 metric 100"
fi
cat > net/routes <<T
$d1
$d2
10.0.0.0/24 dev eth3
10.20.8.0/24 via 10.20.255.2 dev eth1
10.20.0.0/24 via 10.20.255.1 dev eth1
10.30.0.0/24 dev eth4
10.9.0.0/24 dev eth2
default via 203.0.113.1 dev eth0 table backup
10.20.0.0/16 via 10.20.255.1 dev eth1 table dc
T
cat > PLAN.md <<'MD'
# Routing plan (edge router rt-edge-1)

Interfaces
  eth0  uplink to the ISP           gateway 203.0.113.1
  eth1  datacenter link             gateways 10.20.255.1 (default for 10.20.0.0/16) and 10.20.255.2 (storage array, 10.20.8.0/24)
  eth2  backup link                 gateways 10.9.255.1 (DC) and 10.9.255.2 (storage array); backup VLAN is 10.9.0.0/24
  eth3  management network          10.0.0.0/24, directly connected
  eth4  application VLAN            10.30.0.0/24, directly connected

Rules
  Hosts in the backup VLAN use their own routing table `backup` (table 100).
  Everything else to 10.20.0.0/16 uses table `dc` (200). No per-host exceptions are planned.

Every flow below must leave exactly as listed (check with `ip route get DST from SRC`):

   #  from          to              interface  gateway
   1  10.9.0.5      10.20.3.7       eth2       10.9.255.1
   2  10.9.0.5      10.20.8.15      eth2       10.9.255.2
   3  10.9.0.77     10.20.200.1     eth2       10.9.255.1
   4  10.9.0.5      198.51.100.10   eth0       203.0.113.1
   5  10.9.0.5      10.0.0.9        eth3       -
   6  10.30.0.4     10.20.3.7       eth1       10.20.255.1
   7  10.30.0.4     10.20.8.15      eth1       10.20.255.2
   8  10.30.0.4     198.51.100.10   eth0       203.0.113.1
   9  10.0.0.5      10.20.3.7       eth1       10.20.255.1
  10  10.0.0.5      203.0.113.50    eth0       203.0.113.1
  11  10.30.0.4     10.0.0.9        eth3       -
  12  10.50.0.9     10.20.8.15      eth1       10.20.255.2
MD
exit 0
