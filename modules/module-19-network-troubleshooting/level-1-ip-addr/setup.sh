#!/bin/bash
# `ip addr` of app-07, pasted into the ticket. The database network is
# 10.20.0.0/22; exactly one address of the host is inside it: the second
# address on a VLAN of the bond (the first one is in another subnet). VLAN id, addresses and the link state of the
# bond (and so of the VLAN) change per setup.
SANDBOX="$1"

vlan=$((110 + RANDOM % 40))
third=$((1 + RANDOM % 3))              # 10.20.1.x - 10.20.3.x: still inside the /22
host=$((10 + RANDOM % 240))
prim=$((10 + RANDOM % 200))
near=$((10 + RANDOM % 240))            # 10.20.4.x/22: the neighbouring /22
wg=$((2 + RANDOM % 50))
mgmt3=$((RANDOM % 200))
mac4=$(printf '%02x' $((RANDOM % 256)))
mac5=$(printf '%02x' $((RANDOM % 256)))

if [ $((RANDOM % 2)) -eq 0 ]; then
  slave_flags="BROADCAST,MULTICAST,SLAVE,UP,LOWER_UP"; slave_state="UP"
  bond_flags="BROADCAST,MULTICAST,MASTER,UP,LOWER_UP"; bond_state="UP"
  vlan_flags="BROADCAST,MULTICAST,UP,LOWER_UP"; vlan_state="UP"
else
  slave_flags="NO-CARRIER,BROADCAST,MULTICAST,SLAVE,UP"; slave_state="DOWN"
  bond_flags="NO-CARRIER,BROADCAST,MULTICAST,MASTER,UP"; bond_state="DOWN"
  vlan_flags="NO-CARRIER,BROADCAST,MULTICAST,UP,M-DOWN"; vlan_state="LOWERLAYERDOWN"
fi

cat > "$SANDBOX/ip-addr.txt" <<EOF
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute
       valid_lft forever preferred_lft forever
2: eno1: <$slave_flags> mtu 9000 qdisc mq master bond0 state $slave_state group default qlen 1000
    link/ether b8:ca:3a:61:$mac4:$mac5 brd ff:ff:ff:ff:ff:ff
    altname enp24s0f0
3: eno2: <$slave_flags> mtu 9000 qdisc mq master bond0 state $slave_state group default qlen 1000
    link/ether b8:ca:3a:61:$mac4:$mac5 brd ff:ff:ff:ff:ff:ff permaddr b8:ca:3a:61:$mac4:$(printf '%02x' $(( (16#$mac5 + 1) % 256 )))
    altname enp24s0f1
4: ens6f0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 3c:fd:fe:9e:21:$mac4 brd ff:ff:ff:ff:ff:ff
    altname enp59s0f0
    inet 10.20.4.$near/22 brd 10.20.7.255 scope global ens6f0
       valid_lft forever preferred_lft forever
    inet 10.20.5.$wg/22 brd 10.20.7.255 scope global secondary ens6f0
       valid_lft forever preferred_lft forever
    inet6 fe80::3efd:feff:fe9e:21$mac4/64 scope link
       valid_lft forever preferred_lft forever
5: ens6f1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 3c:fd:fe:9e:22:$mac4 brd ff:ff:ff:ff:ff:ff
    altname enp59s0f1
    inet 10.200.$mgmt3.$host/24 brd 10.200.$mgmt3.255 scope global ens6f1
       valid_lft forever preferred_lft forever
6: bond0: <$bond_flags> mtu 9000 qdisc noqueue state $bond_state group default qlen 1000
    link/ether b8:ca:3a:61:$mac4:$mac5 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::baca:3aff:fe61:$mac4$mac5/64 scope link
       valid_lft forever preferred_lft forever
7: bond0.$vlan@bond0: <$vlan_flags> mtu 9000 qdisc noqueue state $vlan_state group default qlen 1000
    link/ether b8:ca:3a:61:$mac4:$mac5 brd ff:ff:ff:ff:ff:ff
    inet 192.168.$vlan.$prim/24 brd 192.168.$vlan.255 scope global bond0.$vlan
       valid_lft forever preferred_lft forever
    inet 10.20.$third.$host/22 brd 10.20.3.255 scope global bond0.$vlan
       valid_lft forever preferred_lft forever
    inet6 fe80::baca:3aff:fe61:$mac4$mac5/64 scope link
       valid_lft forever preferred_lft forever
8: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default
    link/ether 02:42:7e:1d:$mac5:$mac4 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
       valid_lft forever preferred_lft forever
9: wg0: <POINTOPOINT,NOARP,UP,LOWER_UP> mtu 1420 qdisc noqueue state UNKNOWN group default qlen 1000
    link/none
    inet 10.2.0.$wg/32 scope global wg0
       valid_lft forever preferred_lft forever
EOF

cat > "$SANDBOX/TICKET.txt" <<'EOF'
TICKET-5120  app-07: which interface is on the database network?
----------------------------------------------------------------
The billing app on app-07 must bind its database connections to the
host's own address in the database subnet 10.20.0.0/22, otherwise the
DB firewall drops them. The new config needs three values:

  IFACE   the interface that address is configured on (the name ip uses
          for the address, as you would pass it to `ip addr show dev`)
  ADDR    the address itself, without the /prefix
  STATE   the operational state ip reports for that interface

`ip addr` from app-07 is in ip-addr.txt.
EOF
