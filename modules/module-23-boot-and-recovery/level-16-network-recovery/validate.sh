#!/bin/bash
# Parses every sysroot/etc/systemd/network/*.network as systemd would: each NIC (from
# ip-o-link.txt) must be matched by exactly one file, which names it by Name= or
# MACAddress= (never the old eno names or the old MAC), with the ticket's address and
# prefix, a gateway inside the subnet, the old DNS, and no default route on the backup NIC.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
command -v python3 >/dev/null || { echo "❌ validator needs python3"; exit 1; }
if ! cksum ip-o-link.txt ticket.txt 2>/dev/null | cmp -s - .lm-state/sums; then
  echo "❌ ip-o-link.txt or ticket.txt was changed; type 'reset' to get them back"
  exit 1
fi
python3 - <<'PYEOF'
import fnmatch, glob, ipaddress, os, re, sys
def fail(m): print("❌ " + m); sys.exit(1)
nics = {}
for line in open("ip-o-link.txt"):
    m = re.match(r"\d+: (\S+): .*link/ether (\S+)", line)
    if m: nics[m.group(1)] = m.group(2).lower()
(n1, m1), (n2, m2) = [l.split() for l in open(".lm-state/facts").read().splitlines()[:2]]
oldmac = open(".lm-state/facts").read().splitlines()[2].lower()
lan_addr = open(".lm-state/facts").read().splitlines()[3]
t = {}
for line in open("ticket.txt"):
    f = line.split()
    if f and f[0] in ("LAN", "BACKUP"): t[f[0]] = f
lan_gw, lan_dns = t["LAN"][4], t["LAN"][6]
lan_cidr = t["LAN"][2]; bak_cidr = t["BACKUP"][2]
def parse(path):
    secs = []; cur = None
    for n, raw in enumerate(open(path).read().splitlines(), 1):
        s = raw.strip()
        if not s or s[0] in "#;": continue
        if s.startswith("["):
            if not s.endswith("]") or len(s) < 3: fail("%s line %d: bad section header" % (os.path.basename(path), n))
            cur = (s[1:-1], []); secs.append(cur); continue
        if "=" not in s or cur is None: fail("%s line %d: not a Key=Value line inside a section" % (os.path.basename(path), n))
        k, v = s.split("=", 1); cur[1].append((k.strip(), v.strip()))
    return secs
def vals(secs, sec, key):
    out = []
    for name, kv in secs:
        if name == sec: out += [v for k, v in kv if k == key]
    return out
files = sorted(glob.glob("sysroot/etc/systemd/network/*.network"))
if not files: fail("there is no .network file left in sysroot/etc/systemd/network/")
match = {n1: [], n2: []}
for f in files:
    secs = parse(f); base = os.path.basename(f)
    names = " ".join(vals(secs, "Match", "Name")).split()
    macs = [m.lower() for m in " ".join(vals(secs, "Match", "MACAddress")).split()]
    if any(re.fullmatch(r"eno\d*", n.lstrip("!")) or n in ("eno1", "eno2") for n in names):
        fail("%s still matches the old interface name (eno...), which no longer exists" % base)
    if oldmac in macs: fail("%s still matches the old board's MAC address" % base)
    hit = [n for n in nics if (names and any(fnmatch.fnmatch(n, p) for p in names) and (not macs or nics[n] in macs)) or (not names and macs and nics[n] in macs)]
    if not hit:
        fail("%s does not match any NIC that exists in ip-o-link.txt (check [Match])" % base)
    if len(hit) > 1: fail("%s matches more than one NIC; match one interface per file" % base)
    match[hit[0]].append((base, secs))
for nic in (n1, n2):
    if len(match[nic]) == 0: fail("no .network file matches %s" % nic)
    if len(match[nic]) > 1: fail("%s is matched by more than one file (%s): only the first would apply" % (nic, ", ".join(b for b, _ in match[nic])))
base, secs = match[n1][0]
a = vals(secs, "Network", "Address")
if len(a) != 1: fail("%s must have exactly one Address=" % base)
if a[0] != lan_cidr: fail("%s: Address=%s does not match the ticket (address and prefix length)" % (base, a[0]))
net = ipaddress.ip_interface(a[0]).network
gw = vals(secs, "Network", "Gateway")
if gw != [lan_gw]: fail("%s: Gateway= must be the ticket's gateway, exactly once" % base)
if ipaddress.ip_address(gw[0]) not in net: fail("%s: the gateway %s is outside the subnet %s" % (base, gw[0], net))
if vals(secs, "Network", "DNS") != [lan_dns]: fail("%s: DNS= was changed or removed" % base)
if any(v.lower() in ("yes", "true", "ipv4", "ipv6", "1") for v in vals(secs, "Network", "DHCP")): fail("%s: DHCP must stay off" % base)
base, secs = match[n2][0]
a = vals(secs, "Network", "Address")
if a != [bak_cidr]: fail("%s: the backup Address= does not match the ticket" % base)
if vals(secs, "Network", "Gateway") or vals(secs, "Route", "Gateway"): fail("%s: the backup network must not have a gateway" % base)
print("✅ %s and %s are each matched by one file with the ticket's addresses, and the gateway is inside its subnet" % (n1, n2))
PYEOF
