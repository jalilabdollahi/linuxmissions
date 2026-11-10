#!/bin/bash
# Parse etc/hosts the way the resolver does and compare with the expected map; then
# check duplicates, one line per IP, the header lines, the comments and the 10.9 lines.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s etc/hosts ]; then
  echo "❌ etc/hosts is missing or empty"
  exit 1
fi

python3 - <<'PY'
import sys

def entries(path):
    out = []   # (lineno, ip, [names])
    for n, raw in enumerate(open(path).read().splitlines(), 1):
        line = raw.split("#", 1)[0].split()
        if len(line) >= 2:
            out.append((n, line[0], line[1:]))
    return out

orig_lines = open(".lm-state/original.hosts").read().splitlines()
cur_lines = open("etc/hosts").read().splitlines()
if cur_lines == orig_lines:
    print("❌ etc/hosts has not been changed yet")
    sys.exit(1)
cur = entries("etc/hosts")

# 1. The header (localhost + IPv6) lines are untouched and first.
head = [l for l in orig_lines[:5] if l.strip() and not l.startswith("#")] 
active = [l for l in cur_lines if l.strip() and not l.lstrip().startswith("#")]
if active[:len(head)] != head:
    print("❌ the localhost and IPv6 lines must stay unchanged, in the first lines of the file")
    sys.exit(1)

# 2. Decommissioned hosts: no active 10.9.* line, but still present as comments.
for n, ip, names in cur:
    if ip.startswith("10.9."):
        print(f"❌ line {n}: {ip} ({names[0]}) is still active: comment decommissioned hosts out")
        sys.exit(1)
for ip, name in (("10.9.0.5", "legacy-ldap.corp"), ("10.9.0.6", "old-mail.corp")):
    if not any(l.lstrip().startswith("#") and ip in l and name in l for l in cur_lines):
        print(f"❌ the decommissioned entry for {name} was deleted instead of commented out")
        sys.exit(1)

# 3. Comments from the original must all survive.
for l in orig_lines:
    if l.startswith("#") and l not in cur_lines:
        print(f"❌ a comment was lost: {l[:50]}")
        sys.exit(1)

# 4. One line per IP, every name once.
seen_ip, seen_name = {}, {}
for n, ip, names in cur:
    if ip in seen_ip:
        print(f"❌ {ip} is on lines {seen_ip[ip]} and {n}: each address belongs on one line")
        sys.exit(1)
    seen_ip[ip] = n
    for name in names:
        if name in seen_name:
            print(f"❌ the name {name} is listed more than once (lines {seen_name[name]} and {n})")
            sys.exit(1)
        seen_name[name] = n

# 5. The effective resolution (first line wins) is unchanged.
want = dict(l.split() for l in open(".lm-state/expected.map").read().splitlines())
got = {name: ip for _, ip, names in cur for name in names}
for name in sorted(want):
    if name not in got:
        print(f"❌ {name} no longer resolves: it was lost in the cleanup")
        sys.exit(1)
    if got[name] != want[name]:
        print(f"❌ {name} now resolves to {got[name]}, but today it resolves to {want[name]}")
        sys.exit(1)
extra = sorted(set(got) - set(want))
if extra:
    print(f"❌ unexpected name(s) in the file: {', '.join(extra)}")
    sys.exit(1)
print("✅ one line per address, no duplicates, legacy hosts commented out, every name resolves as before")
PY
