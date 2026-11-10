#!/bin/bash
SB="$1"; cd "$SB" || exit 1
IP="$(cd "$(dirname "$0")" && pwd)/ip"
FLOWS='1 10.9.0.5 10.20.3.7 eth2 10.9.255.1
2 10.9.0.5 10.20.8.15 eth2 10.9.255.2
3 10.9.0.77 10.20.200.1 eth2 10.9.255.1
4 10.9.0.5 198.51.100.10 eth0 203.0.113.1
5 10.9.0.5 10.0.0.9 eth3 -
6 10.30.0.4 10.20.3.7 eth1 10.20.255.1
7 10.30.0.4 10.20.8.15 eth1 10.20.255.2
8 10.30.0.4 198.51.100.10 eth0 203.0.113.1
9 10.0.0.5 10.20.3.7 eth1 10.20.255.1
10 10.0.0.5 203.0.113.50 eth0 203.0.113.1
11 10.30.0.4 10.0.0.9 eth3 -
12 10.50.0.9 10.20.8.15 eth1 10.20.255.2'
check() {   # dir label
  local bad=0 first=""
  while read -r n src dst dev gw; do
    out=$(LM_IPDIR="$1" python3 "$IP" route get "$dst" from "$src" 2>&1 | head -1)
    gotdev=$(sed -n 's/.* dev \([^ ]*\).*/\1/p' <<<"$out"); gotgw=$(sed -n 's/.* via \([^ ]*\).*/\1/p' <<<"$out"); [ -z "$gotgw" ] && gotgw=-
    if [ "$gotdev" != "$dev" ] || [ "$gotgw" != "$gw" ]; then bad=$((bad+1)); [ -z "$first" ] && first="flow $n ($src -> $dst) goes via ${gotdev:-nothing} ${gotgw}"; fi
  done <<<"$FLOWS"
  if [ "$bad" -gt 0 ]; then echo "❌ $bad of 12 planned flows are wrong$2: $first"; return 1; fi
}
check net "" || exit 1
mkdir -p .lm/rev; cp net/rt_tables net/rules .lm/rev/; tac net/routes > .lm/rev/routes
check .lm/rev " (and the result depends on the order routes are listed: break the metric tie)" || exit 1
echo "✅ all 12 flows in PLAN.md take their planned route, independent of route order"
