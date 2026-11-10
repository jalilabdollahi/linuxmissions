#!/bin/bash
# $1 = sandbox path
# allow.cidr: ~60 allowlist entries with redundant ones mixed in (random
# networks per setup). Traps: entries with host bits set (10.1.2.77/24),
# bare host addresses (= /32), the same network written twice in different
# ways, IPv6 entries, inline comments. blocked.log: kernel firewall lines
# whose SRC (not DST) matters; IPv6 addresses are logged fully expanded.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

python3 - <<'PY'
import ipaddress as ipa, random

r = random.Random()
entries = []            # (text, comment)
used = []

def free(n):
    return not any(n.overlaps(u) for u in used)

def pick(prefix_choices, pool):
    while True:
        base = r.choice(pool)
        p = r.choice(prefix_choices)
        addr = ipa.ip_address(int(base.network_address) + r.randrange(base.num_addresses))
        n = ipa.ip_network(f"{addr}/{p}", strict=False)
        if free(n):
            used.append(n)
            return n

pools = [ipa.ip_network(x) for x in ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "100.64.0.0/10")]
public = [ipa.ip_network(x) for x in ("203.0.113.0/24", "198.51.100.0/24", "192.0.2.0/24", "185.0.0.0/8", "91.0.0.0/8")]
labels = ["office", "vpn pool", "build farm", "monitoring", "backup site", "partner", "jump hosts", "k8s nodes",
          "dc2", "lab", "payroll vendor", "support desk", "ci runners", "branch", "scanner", "nat gw"]

big = [pick([12, 14, 16], pools) for _ in range(5)]
mid = [pick([20, 21, 22, 23, 24], pools) for _ in range(28)]
pub = [pick([24, 26, 27, 28, 29, 32], public) for _ in range(12)]
plain = big + mid + pub
for n in plain:
    if n.prefixlen == 32 and r.random() < 0.6:
        text = str(n.network_address)                       # bare address = /32
    elif n.prefixlen < 32 and r.random() < 0.25:
        host = ipa.ip_address(int(n.network_address) + r.randrange(1, n.num_addresses - 1))
        text = f"{host}/{n.prefixlen}"                       # host bits set
    else:
        text = str(n)
    entries.append([text, r.choice(labels)])

# redundant entries: subnets of an existing bigger entry
redundant_texts = []
for parent in r.sample(big + mid[:10], 7):
    sub_len = min(32, parent.prefixlen + r.choice([2, 4, 6, 8]))
    sub = list(parent.subnets(new_prefix=sub_len))[r.randrange(2 ** (sub_len - parent.prefixlen))]
    text = str(sub) if r.random() < 0.7 or sub_len > 30 else f"{ipa.ip_address(int(sub.network_address) + 1)}/{sub_len}"
    entries.append([text, r.choice(labels)])
# the same network twice: the later line is the redundant one
twin = r.choice([n for n in mid if n.prefixlen <= 24])
host = ipa.ip_address(int(twin.network_address) + r.randrange(2, 200))
twin_entry = [f"{host}/{twin.prefixlen}", "added again by CHG-2207"]
# two adjacent networks: neither covers the other
adj = pick([24], pools[:1])
adj2 = ipa.ip_network(f"{ipa.ip_address(int(adj.network_address) + 256)}/24")
if free(adj2):
    used.append(adj2)
    entries.append([str(adj), "lab A"])
    entries.append([str(adj2), "lab B"])
# a host inside a public range already listed
pub_parent = r.choice([n for n in pub if n.prefixlen <= 27])
entries.append([str(ipa.ip_address(int(pub_parent.network_address) + 5)), "partner bastion"])
# IPv6: a /48 and a /64 inside it, plus an unrelated /64
v6a = ipa.ip_network(f"2001:db8:{r.randrange(0x100, 0xfff):x}::/48")
v6b = list(v6a.subnets(new_prefix=64))[r.randrange(1, 4000)]
v6c = ipa.ip_network(f"2001:db8:{r.randrange(0x1000, 0xffff):x}:{r.randrange(1, 0xffff):x}::/64")
entries += [[str(v6a), "dc2 v6"], [str(v6b), "dc2 mgmt v6"], [str(v6c), "office v6"]]

r.shuffle(entries)
# the twin goes after its original
pos = next(i for i, e in enumerate(entries) if ipa.ip_network(e[0], strict=False) == twin)
entries.insert(r.randrange(pos + 1, len(entries) + 1), twin_entry)

with open("allow.cidr", "w") as f:
    f.write("# fw01 source allowlist (NET-1840). One entry per line; a bare address means /32.\n"
            "# Anything after # is a comment.\n")
    for text, label in entries:
        f.write(f"{text:<26}# {label}\n" if r.random() < 0.85 else f"{text}\n")

nets = [ipa.ip_network(t, strict=False) for t, _ in entries]

v4nets = [n for n in nets if n.version == 4]

def inside():
    n = r.choice(v4nets)
    return ipa.ip_address(int(n.network_address) + r.randrange(n.num_addresses))

def outside(v6=False):
    while True:
        a = ipa.ip_address(r.getrandbits(128) | (0x2001 << 112)) if v6 else ipa.ip_address(
            f"{r.choice([45, 62, 77, 89, 103, 141, 176, 193, 212])}.{r.randrange(256)}.{r.randrange(256)}.{r.randrange(1, 255)}")
        if not any(a in n for n in nets if n.version == a.version):
            return a

srcs_in = [inside() for _ in range(6)]
v6net = r.choice([v6b, v6c])
srcs_in.append(ipa.ip_address(int(v6net.network_address) + r.randrange(1, 9999)))
srcs_out = [outside() for _ in range(25)] + [outside(True) for _ in range(2)]
dsts = [inside() for _ in range(4)] + [ipa.ip_address(f"10.250.0.{r.randrange(2, 60)}")]
dst6 = ipa.ip_address(int(v6a.network_address) + 0x10)
seq = srcs_in + [r.choice(srcs_in) for _ in range(20)] + [r.choice(srcs_out) for _ in range(150)]
r.shuffle(seq)

def fmt(a):
    return a.exploded if a.version == 6 else str(a)

lines = []
t = 3600 * 2
for src in seq:
    t += r.randrange(1, 40)
    hh, mm, ss = t // 3600, t // 60 % 60, t % 60
    proto, dpt = r.choice([("TCP", 22), ("TCP", 443), ("TCP", 3389), ("UDP", 161), ("TCP", 8443), ("TCP", 5432)])
    if src.version == 4:
        ip_part = (f"MAC=00:1c:73:aa:10:01:00:1c:73:bb:20:02:08:00 SRC={src} DST={r.choice(dsts)} LEN=60 "
                   f"TOS=0x00 PREC=0x00 TTL={r.randrange(40, 120)} ID={r.randrange(65535)} DF")
    else:
        ip_part = (f"MAC=00:1c:73:aa:10:01:00:1c:73:bb:20:02:86:dd SRC={fmt(src)} DST={fmt(dst6)} LEN=80 "
                   f"TC=0 HOPLIMIT={r.randrange(40, 64)} FLOWLBL={r.randrange(1 << 20)}")
    tail = "WINDOW=64240 RES=0x00 SYN URGP=0" if proto == "TCP" else "LEN=40"
    lines.append(f"Nov 10 {hh:02d}:{mm:02d}:{ss:02d} fw01 kernel: [{t + 81234}.{r.randrange(10**6):06d}] [UFW BLOCK] "
                 f"IN=eth0 OUT= {ip_part} PROTO={proto} SPT={r.randrange(1024, 65535)} DPT={dpt} {tail}")
with open("blocked.log", "w") as f:
    f.write("\n".join(lines) + "\n")
PY

cat > TICKET.txt <<'EOF'
NET-1902  fw01 allowlist cleanup

1. allow.cidr has grown to about 60 entries. Before we tidy it up, list
   every entry that is fully covered by ANOTHER single entry of the list
   (it adds nothing). If the very same network is listed twice, the line
   further down is the redundant one. Write them to redundant.txt, one per
   line, exactly as they are written in allow.cidr (without the comment).
   IPv6 entries count too.

2. Partners say they are being blocked although they are on the list.
   blocked.log is fw01's kernel log of blocked packets. Write every source
   address (SRC=) from blocked.log that IS inside some allowlist entry to
   misblocked.txt, one address per line, each address once.
EOF
