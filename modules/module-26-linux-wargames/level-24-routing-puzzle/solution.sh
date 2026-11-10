#!/bin/bash
export PATH="$PWD/bin:$PATH"
ip rule
ip route show table all
ip rule del priority 50
ip route add 10.20.0.0/16 via 10.9.255.1 dev eth2 table backup
ip route add 10.20.8.0/24 via 10.9.255.2 dev eth2 table backup
ip route add 10.20.8.0/24 via 10.20.255.2 dev eth1 table dc
ip route add 10.0.0.0/24 dev eth3 table backup
ip route del default via 10.20.255.1 dev eth1 metric 100
ip route add default via 10.20.255.1 dev eth1 metric 300
ip route get 10.20.8.15 from 10.9.0.5
