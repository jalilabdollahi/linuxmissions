#!/bin/bash
# $1 = sandbox path
# Three `ip neigh` captures of VLAN 30 taken five minutes apart, the VLAN
# inventory and an IEEE OUI excerpt. One inventory IP flips between its real
# MAC and a rogue one (random host, random rogue vendor). Traps: the 09:05
# capture came from the NOC tool and has upper-case MACs, one host is FAILED
# (no lladdr) in one capture, and there are lines for other interfaces.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p captures

python3 - <<'PY'
import random

r = random.Random()

def mac(prefix):
    return prefix.lower().replace("-", ":") + ":" + ":".join(f"{r.randrange(256):02x}" for _ in range(3))

# (OUI, organisation) as they appear in the IEEE list
known_vendors = {
    "arista": ("44-4C-A8", "Arista Networks"),
    "dell":   ("18-66-DA", "Dell Inc."),
    "smc":    ("AC-1F-6B", "Super Micro Computer, Inc."),
    "hpe":    ("94-57-A5", "Hewlett Packard"),
    "intel":  ("3C-FD-FE", "Intel Corporate"),
    "vmware": ("00-50-56", "VMware, Inc."),
    "syno":   ("00-11-32", "Synology Incorporated"),
}
rogue_vendors = [
    ("DC-A6-32", "Raspberry Pi Trading Ltd"),
    ("E4-5F-01", "Raspberry Pi Trading Ltd"),
    ("24-0A-C4", "Espressif Inc."),
    ("50-C7-BF", "TP-LINK TECHNOLOGIES CO.,LTD."),
    ("00-0E-C6", "ASIX ELECTRONICS CORP."),
    ("00-E0-4C", "REALTEK SEMICONDUCTOR CORP."),
    ("F0-9F-C2", "Ubiquiti Inc"),
]
filler = [
    ("00-1B-21", "Intel Corporate"), ("00-1A-A0", "Dell Inc."), ("00-25-90", "Super Micro Computer, Inc."),
    ("00-17-A4", "Hewlett Packard"), ("00-1C-73", "Arista Networks"), ("00-05-73", "Cisco Systems, Inc"),
    ("00-0C-29", "VMware, Inc."), ("00-15-5D", "Microsoft Corporation"), ("30-AE-A4", "Espressif Inc."),
    ("B8-27-EB", "Raspberry Pi Foundation"), ("28-6F-B9", "Nokia Shanghai Bell Co., Ltd."),
    ("00-1E-C9", "Dell Inc."), ("A4-BF-01", "Intel Corporate"), ("70-B5-E8", "Dell Inc."),
    ("00-04-96", "Extreme Networks, Inc."), ("00-90-0B", "LANNER ELECTRONICS, INC."),
    ("FC-EC-DA", "Ubiquiti Inc"), ("00-23-24", "G-PRO COMPUTER"), ("08-00-27", "PCS Systemtechnik GmbH"),
]

hosts = [("10.30.0.1", "gw-vlan30", "arista")]
octets = r.sample(range(10, 250), 9)
roles = [("nfs-01", "syno"), ("db-01", "dell"), ("db-02", "dell"), ("app-01", "smc"), ("app-02", "smc"),
         ("app-03", "hpe"), ("build-01", "intel"), ("mon-01", "vmware"), ("backup-01", "hpe")]
for o, (name, v) in zip(sorted(octets), roles):
    hosts.append((f"10.30.0.{o}", name, v))
macs = {ip: mac(known_vendors[v][0]) for ip, _, v in hosts}

victim = r.choice(hosts[:6])[0]
roui, rorg = r.choice(rogue_vendors)
rogue = mac(roui)
pattern = r.choice([("k", "r", "k"), ("r", "k", "r")])
# The FAILED decoy: a different host is unreachable in one capture
failed_ip = r.choice([h[0] for h in hosts if h[0] != victim and h[0] != "10.30.0.1"])
failed_at = r.randrange(3)
incomplete = f"10.30.0.{r.choice([o for o in range(2, 254) if f'10.30.0.{o}' not in macs])}"

with open("vlan30-inventory.csv", "w") as f:
    f.write("ip,hostname,mac\n")
    for ip, name, _ in hosts:
        f.write(f"{ip},{name},{macs[ip].upper()}\n")

mgmt = [(f"10.10.0.{o}", mac(r.choice(filler)[0])) for o in r.sample(range(2, 60), 2)]
b = [int(x, 16) for x in macs["10.30.0.1"].split(":")]
eui = [b[0] ^ 2, b[1], b[2], 0xFF, 0xFE, b[3], b[4], b[5]]
gw6 = "fe80::" + ":".join(f"{(eui[i] << 8) | eui[i + 1]:x}" for i in range(0, 8, 2))

times = ["09:00:02", "09:05:01", "09:10:03"]
states = ["REACHABLE", "STALE", "DELAY", "STALE", "STALE", "REACHABLE"]
for i, t in enumerate(times):
    lines = []
    for ip, _, _ in hosts:
        m = macs[ip]
        if ip == victim and pattern[i] == "r":
            m = rogue
        if ip == failed_ip and i == failed_at:
            lines.append(f"{ip} dev eth0.30 FAILED")
            continue
        st = "REACHABLE" if ip == victim else r.choice(states)
        lines.append(f"{ip} dev eth0.30 lladdr {m} {st}")
    if i != 1:
        lines.append(f"{incomplete} dev eth0.30 INCOMPLETE")
    for ip, m in mgmt:
        lines.append(f"{ip} dev eth0 lladdr {m} {r.choice(states)}")
    lines.append(f"{gw6} dev eth0.30 lladdr {macs['10.30.0.1']} router STALE")
    r.shuffle(lines)
    if i == 1:
        # The NOC tool shows MACs in upper case
        lines = [l.replace(l.split("lladdr ")[1].split()[0], l.split("lladdr ")[1].split()[0].upper())
                 if "lladdr" in l else l for l in lines]
        head = (f"# pasted from NOC ticket NOC-4471 (their collector upper-cases MAC addresses)\n"
                f"# app-jump-02, Tue Nov 10 {t} UTC 2026, `ip neigh show`\n")
    else:
        head = f"# app-jump-02, Tue Nov 10 {t} UTC 2026, `ip neigh show`\n"
    with open(f"captures/neigh-{t[:5].replace(':', '')}.txt", "w") as f:
        f.write(head + "\n".join(lines) + "\n")

entries = filler + list(known_vendors.values()) + rogue_vendors
seen, uniq = set(), []
for oui, org in entries:
    if oui not in seen:
        seen.add(oui)
        uniq.append((oui, org))
uniq.sort()
with open("oui.txt", "w") as f:
    f.write("OUI/MA-L                                                    Organization\n"
            "company_id                                                  Organization\n"
            "                                                            Address\n\n")
    for oui, org in uniq:
        f.write(f"{oui}   (hex)\t\t{org}\n{oui.replace('-', '')}     (base 16)\t\t{org}\n"
                f"\t\t\t\t(address omitted in this excerpt)\n\n")
PY

cat > TICKET.txt <<'EOF'
NET-5108  Intermittent outages on VLAN 30

For an hour now, hosts on VLAN 30 lose connectivity for a minute or two at a
time, then recover. Classic symptom of two devices answering ARP for the same
IP. We grabbed the ARP/neighbour table of app-jump-02 three times, five
minutes apart (captures/), plus the VLAN inventory and the IEEE OUI list.

Please find the IPv4 address whose MAC address keeps changing, both MACs we
see for it, and the vendor of the MAC that is NOT the one in our inventory,
so facilities knows what kind of box to look for. Put it in conflict.env:

IP=...
KNOWN_MAC=...
ROGUE_MAC=...
ROGUE_VENDOR=...
EOF
