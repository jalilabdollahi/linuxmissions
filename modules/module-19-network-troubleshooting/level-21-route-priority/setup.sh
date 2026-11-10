#!/bin/bash
# $1 = sandbox path
# A laptop on Ethernet, Wi-Fi and a split-tunnel VPN with policy routing.
# ip-rule.txt / ip-route-all.txt are `ip rule` and `ip route show table all`
# (random subnets, metrics and table id). Traps baked into flows.txt:
#   - the source address doesn't pick the default route; the lower metric does
#   - the "to CORP" rule (pref 32765) sends traffic to the VPN table before
#     main is consulted, although main has a MORE specific route for it
#   - the VPN-source rule hits a table without a default and falls through
SANDBOX="$1"
cd "$SANDBOX" || exit 1

python3 - <<'PY'
import random

r = random.Random()
eth_net = f"192.168.{r.randrange(2, 60)}"
wifi_net = f"172.{r.randrange(16, 31)}.{r.randrange(0, 250, 4)}"
vpn_net = f"10.{r.choice([8, 9, 13, 66])}.0"
corp_a = r.choice([100, 110, 120, 140])
corp = f"10.{corp_a}.0.0/16"
eth_ip, wifi_ip, vpn_ip = f"{eth_net}.{r.randrange(20, 90)}", f"{wifi_net}.{r.randrange(20, 200)}", f"{vpn_net}.{r.randrange(2, 30)}"
eth_gw, wifi_gw, vpn_gw = f"{eth_net}.1", f"{wifi_net}.1", f"{vpn_net}.1"
office_gw = f"{eth_net}.254"
table = r.choice(["51820", "200", "1000"])
eth_metric = r.choice([100, 20100])     # 20100 = NetworkManager's "less preferred" ethernet
wifi_metric = 600
# a few more-specific corp routes the old office router still announces on eth0
legacy = f"10.{corp_a}.{r.randrange(1, 250)}.0/24"

rules = [
    "0:\tfrom all lookup local",
    f"32764:\tfrom {vpn_ip} lookup {table}",
    f"32765:\tfrom all to {corp} lookup {table}",
    "32766:\tfrom all lookup main",
    "32767:\tfrom all lookup default",
]
with open("ip-rule.txt", "w") as f:
    f.write("laptop-jk$ ip rule\n" + "\n".join(rules) + "\n")

eth_gw_line = f"default via {eth_gw} dev eth0 proto dhcp src {eth_ip} metric {eth_metric}"
wifi_gw_line = f"default via {wifi_gw} dev wlan0 proto dhcp src {wifi_ip} metric {wifi_metric}"
routes = [
    *sorted([eth_gw_line, wifi_gw_line], key=lambda l: int(l.split()[-1])),
    f"{vpn_net}.0/24 dev wg0 proto kernel scope link src {vpn_ip}",
    f"{legacy} via {office_gw} dev eth0 proto static metric 100",
    f"{eth_net}.0/24 dev eth0 proto kernel scope link src {eth_ip} metric {eth_metric}",
    f"{wifi_net}.0/22 dev wlan0 proto kernel scope link src {wifi_ip} metric {wifi_metric}",
    f"{corp} via {vpn_gw} dev wg0 table {table} proto static",
    f"{vpn_net}.0/24 dev wg0 table {table} proto static scope link",
    f"10.{corp_a + 1}.0.0/16 via {vpn_gw} dev wg0 table {table} proto static",
    f"local {eth_ip} dev eth0 table local proto kernel scope host src {eth_ip}",
    f"broadcast {eth_net}.255 dev eth0 table local proto kernel scope link src {eth_ip}",
    f"local {wifi_ip} dev wlan0 table local proto kernel scope host src {wifi_ip}",
    f"local {vpn_ip} dev wg0 table local proto kernel scope host src {vpn_ip}",
    "local 127.0.0.0/8 dev lo table local proto kernel scope host src 127.0.0.1",
    "local 127.0.0.1 dev lo table local proto kernel scope host src 127.0.0.1",
    "broadcast 127.255.255.255 dev lo table local proto kernel scope link src 127.0.0.1",
]
with open("ip-route-all.txt", "w") as f:
    f.write("laptop-jk$ ip route show table all\n" + "\n".join(routes) + "\n")

leg_host = legacy.replace(".0/24", f".{r.randrange(2, 250)}")
flows = [
    (eth_ip, f"{r.choice([8, 9, 1])}.{r.randrange(1, 250)}.{r.randrange(1, 250)}.{r.randrange(1, 250)}", "software update download"),
    (wifi_ip, f"151.101.{r.randrange(1, 250)}.{r.randrange(1, 250)}", "video call, app bound to the Wi-Fi address"),
    (vpn_ip, f"10.{corp_a}.{r.randrange(1, 250)}.{r.randrange(2, 250)}", "ssh to a build server over the VPN"),
    (vpn_ip, f"140.82.{r.randrange(112, 127)}.{r.randrange(2, 250)}", "git push, client bound to the VPN address"),
    (eth_ip, leg_host, "wiki on the old office subnet"),
    (wifi_ip, f"{eth_net}.{r.randrange(100, 250)}", "printer on the docking-station LAN"),
]
r.shuffle(flows)
with open("flows.txt", "w") as f:
    f.write("# source           destination       what\n")
    for s, d, what in flows:
        f.write(f"{s:<18} {d:<17} {what}\n")
PY

cat > TICKET.txt <<'EOF'
HELP-3317  "Some things go over the VPN, some don't, and I can't tell which"

My laptop is docked (eth0), on Wi-Fi (wlan0) and on the split-tunnel VPN
(wg0) all at once. ip-rule.txt and ip-route-all.txt are what the laptop says.
For each flow in flows.txt (source address, destination), tell me which
gateway and which interface the kernel will use.

Answer in flows.tsv, one line per flow, in the order of flows.txt:
  source  destination  gateway  device
Use the gateway's IP, or the word "direct" when the destination is on a
directly connected network (no "via").
EOF
