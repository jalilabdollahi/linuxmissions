#!/bin/bash
# $1 = sandbox path
# Computes both answers from allow.cidr and blocked.log with Python's
# ipaddress (strict=False, so host bits are allowed; bare address = /32;
# IPv4 and IPv6 compared separately), then compares the two files.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

python3 - <<'PY'
import ipaddress as ipa, re, sys

def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

entries = []
for line in open("allow.cidr"):
    text = line.split("#", 1)[0].strip()
    if text:
        entries.append((text, ipa.ip_network(text, strict=False)))
redundant = set()
for i, (text, n) in enumerate(entries):
    for j, (_, m) in enumerate(entries):
        if i != j and n.version == m.version and n.subnet_of(m) and (n != m or j < i):
            redundant.add(text)
            break
nets = [n for _, n in entries]
srcs = {ipa.ip_address(s) for s in re.findall(r"\bSRC=(\S+)", open("blocked.log").read())}
misblocked = {a for a in srcs if any(a.version == n.version and a in n for n in nets)}

def lines(name):
    try:
        raw = open(name, encoding="utf-8", errors="replace").read().replace("\r", "")
    except FileNotFoundError:
        fail(f"{name} does not exist yet")
    return [l.split("#", 1)[0].strip() for l in raw.splitlines() if l.split("#", 1)[0].strip()]

got = lines("redundant.txt")
if len(got) != len(set(got)):
    fail("redundant.txt lists an entry more than once")
texts = {t for t, _ in entries}
for g in got:
    if g not in texts:
        try:
            n = ipa.ip_network(g, strict=False)
        except ValueError:
            fail(f"redundant.txt: '{g}' is not an entry of allow.cidr")
        same = [t for t, m in entries if m == n]
        if same:
            fail(f"redundant.txt: write entries exactly as allow.cidr has them ('{g}' is written differently there)")
        fail(f"redundant.txt: '{g}' is not an entry of allow.cidr")
extra = [g for g in got if g not in redundant]
if extra:
    n = dict(entries)[extra[0]]
    twins = [t for t, m in entries if m == n and t != extra[0]]
    if twins:
        fail(f"redundant.txt: '{extra[0]}' and '{twins[0]}' are the same network; only the one further down the file is redundant")
    fail(f"redundant.txt: '{extra[0]}' is not covered by any single other entry")
missing = sorted(redundant - set(got))
if missing:
    v6 = [m for m in missing if ":" in m]
    if v6 and len(v6) == len(missing):
        fail(f"redundant.txt misses {len(missing)} entr{'y' if len(missing) == 1 else 'ies'}: IPv6 entries count too")
    fail(f"redundant.txt misses {len(missing)} redundant entr{'y' if len(missing) == 1 else 'ies'} "
         "(host bits set still means the whole network, and a bare address is a /32)")

got = lines("misblocked.txt")
try:
    addrs = [ipa.ip_address(g) for g in got]
except ValueError as e:
    fail(f"misblocked.txt: {e} (one address per line, nothing else)")
if len(addrs) != len(set(addrs)):
    fail("misblocked.txt lists an address more than once")
wrong = [a for a in addrs if a not in misblocked]
if wrong:
    if wrong[0] not in srcs:
        fail(f"misblocked.txt: {wrong[0]} is not a source (SRC=) in blocked.log")
    fail(f"misblocked.txt: {wrong[0]} is not inside any allowlist entry")
miss = misblocked - set(addrs)
if miss:
    v6 = [a for a in miss if a.version == 6]
    if v6 and len(v6) == len(miss):
        fail("misblocked.txt misses an IPv6 source (the kernel logs IPv6 addresses fully written out)")
    fail(f"misblocked.txt misses {len(miss)} source address(es) that are inside the allowlist")
print(f"✅ {len(redundant)} redundant entries and {len(misblocked)} wrongly blocked sources found")
PY
