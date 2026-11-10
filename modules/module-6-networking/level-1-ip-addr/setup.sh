#!/bin/bash
SANDBOX="$1"

# `ip addr` output from app-07 (iproute2 6.x), pasted into the ticket.
cat > "$SANDBOX/ip_addr.txt" <<'EOF'
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute 
       valid_lft forever preferred_lft forever
2: eno1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 3c:ec:ef:12:9a:41 brd ff:ff:ff:ff:ff:ff
    altname enp3s0f0
    inet 10.20.4.17/24 brd 10.20.4.255 scope global eno1
       valid_lft forever preferred_lft forever
    inet 10.20.4.50/24 brd 10.20.4.255 scope global secondary eno1
       valid_lft forever preferred_lft forever
    inet6 fe80::3eec:efff:fe12:9a41/64 scope link 
       valid_lft forever preferred_lft forever
3: eno2: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN group default qlen 1000
    link/ether 3c:ec:ef:12:9a:42 brd ff:ff:ff:ff:ff:ff
    altname enp3s0f1
4: wlp2s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether a4:c3:f0:85:2e:19 brd ff:ff:ff:ff:ff:ff
    inet 192.168.1.73/24 brd 192.168.1.255 scope global dynamic noprefixroute wlp2s0
       valid_lft 85912sec preferred_lft 85912sec
    inet6 2a02:8108:1c40:5e00:a6c3:f0ff:fe85:2e19/64 scope global dynamic mngtmpaddr noprefixroute 
       valid_lft 7012sec preferred_lft 3412sec
    inet6 fe80::a6c3:f0ff:fe85:2e19/64 scope link noprefixroute 
       valid_lft forever preferred_lft forever
5: eno1.120@eno1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 3c:ec:ef:12:9a:41 brd ff:ff:ff:ff:ff:ff
    inet 172.16.120.5/22 brd 172.16.123.255 scope global eno1.120
       valid_lft forever preferred_lft forever
    inet6 fe80::3eec:efff:fe12:9a41/64 scope link 
       valid_lft forever preferred_lft forever
6: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default 
    link/ether 02:42:5b:7c:11:0a brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
       valid_lft forever preferred_lft forever
7: wg0: <POINTOPOINT,NOARP,UP,LOWER_UP> mtu 1420 qdisc noqueue state UNKNOWN group default qlen 1000
    link/none 
    inet 10.66.0.2/32 scope global wg0
       valid_lft forever preferred_lft forever
EOF
