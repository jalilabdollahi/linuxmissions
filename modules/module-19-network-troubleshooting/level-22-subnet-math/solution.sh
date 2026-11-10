#!/bin/bash
# Python's ipaddress does the CIDR maths (strict=False accepts host bits).
cat > cidr.py <<'PY'
import ipaddress as ip, re
entries = [(t, ip.ip_network(t, strict=False))
           for t in (l.split("#")[0].strip() for l in open("allow.cidr")) if t]
with open("redundant.txt", "w") as out:
    for i, (t, n) in enumerate(entries):
        if any(i != j and n.version == m.version and n.subnet_of(m) and (n != m or j < i)
               for j, (_, m) in enumerate(entries)):
            print(t, file=out)
srcs = {ip.ip_address(s) for s in re.findall(r"SRC=(\S+)", open("blocked.log").read())}
with open("misblocked.txt", "w") as out:
    for a in sorted(srcs, key=lambda a: (a.version, a)):
        if any(a.version == n.version and a in n for _, n in entries):
            print(a, file=out)
PY
python3 cidr.py
cat redundant.txt misblocked.txt
