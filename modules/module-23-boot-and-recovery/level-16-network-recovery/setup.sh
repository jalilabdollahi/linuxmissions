#!/bin/bash
# Boots Without Network. After a mainboard swap the NICs are named enp<N>s0 and have new
# MACs. 10-lan.network matches Name=eno1 and has a /25 whose range does not contain its
# gateway; 20-backup.network matches the OLD board's MAC. The ticket gives the new plan
# (random addresses, prefix /22-/24), ip-o-link.txt the new names and MACs.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p sysroot/etc/systemd/network .lm-state
R() { echo $((RANDOM % $1)); }
mac() { printf '%02x:%02x:%02x:%02x:%02x:%02x' $(( (RANDOM % 64) * 4 + 2 )) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)); }
HOST=$(printf '%s\n' web-03 db-02 app-07 edge-01 | sed -n "$(( $(R 4) + 1 ))p")
S1=$(( 2 + $(R 6) )); S2=$((S1 + 1))
NIF1=enp${S1}s0; NIF2=enp${S2}s0
M1=$(mac); M2=$(mac); OLDM=$(mac)
PFX=$(( 22 + $(R 3) ))                   # 22, 23 or 24
BLOCK=$(( 1 << (24 - PFX) ))             # /24 blocks in the subnet
BASE3=$(( ($(R 60) + 4) * 4 ))           # third octet of the network, multiple of 4
HOSTO=$(( 10 + $(R 200) ))
GW3=$(( BASE3 + BLOCK - 1 ))
B3=$(( $(R 50) + 100 ))
cat > ip-o-link.txt <<EOT
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000\    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: $NIF1: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000\    link/ether $M1 brd ff:ff:ff:ff:ff:ff
3: $NIF2: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000\    link/ether $M2 brd ff:ff:ff:ff:ff:ff
EOT
cat > ticket.txt <<EOT
CHG-$((2000 + RANDOM % 900)): mainboard replacement on $HOST
The old board's NICs were eno1 (LAN) and eno2 (backup network). The new board has new
MAC addresses, so the kernel names them differently (see ip-o-link.txt, captured from
the rescue system). Address plan, one line per NIC, matched by MAC:

role    mac                 address             gateway              dns
LAN     $M1  10.40.$BASE3.$HOSTO/$PFX  gw 10.40.$GW3.254  dns 10.40.0.2
BACKUP  $M2  172.20.$B3.$HOSTO/24  gw none

The backup network is isolated: it must not get a default route.
EOT
cat > sysroot/etc/systemd/network/10-lan.network <<EOT
[Match]
Name=eno1

[Network]
DHCP=no
Address=10.40.$BASE3.$HOSTO/25
Gateway=10.40.$GW3.254
DNS=10.40.0.2
EOT
cat > sysroot/etc/systemd/network/20-backup.network <<EOT
[Match]
MACAddress=$OLDM

[Network]
DHCP=no
Address=172.20.$B3.$HOSTO/24
EOT
printf '%s\n' "$NIF1 $M1" "$NIF2 $M2" "$OLDM" "$BASE3.$HOSTO/$PFX" > .lm-state/facts
cp -a sysroot/etc/systemd/network .lm-state/orig
cksum ip-o-link.txt ticket.txt > .lm-state/sums
