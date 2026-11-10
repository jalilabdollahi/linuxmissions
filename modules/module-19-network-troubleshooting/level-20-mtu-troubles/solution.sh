#!/bin/bash
# Binary search: lo always gets through, hi never does. ~8 probes.
PATH="$PWD/bin:$PATH"
lo=1200 hi=1472
while [ $((hi - lo)) -gt 1 ]; do
  mid=$(( (lo + hi) / 2 ))
  if vpnping 10.99.0.1 "$mid" >/dev/null; then lo=$mid; else hi=$mid; fi
done
echo $((lo + 28)) > pmtu.txt
sed -i.bak "s/mtu: 1500/mtu: $((lo + 28))/" netplan/60-vpn.yaml && rm netplan/60-vpn.yaml.bak
cat pmtu.txt
grep mtu netplan/60-vpn.yaml
