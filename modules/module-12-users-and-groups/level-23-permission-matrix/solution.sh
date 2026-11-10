#!/bin/bash
python3 - <<'PYEOF'
users = ["kim", "tomas", "priya", "wen", "alex"]
prim, mem = {}, {}
for l in open("etc/passwd"):
    f = l.strip().split(":"); prim[f[0]] = f[3]
gid2n = {}
for l in open("etc/group"):
    n, _, gid, m = l.strip().split(":"); gid2n[gid] = n; mem[n] = m.split(",")
st = {}
for l in open("stat.txt"):
    mode, o, g, p = l.split(); st[p] = (mode, o, g)
def bits(u, p):
    mode, o, g = st[p]
    mine = {gid2n[prim[u]]} | {n for n, m in mem.items() if u in m}
    return mode[1:4] if u == o else mode[4:7] if g in mine else mode[7:10]
out = ["user,path,read,write"]
for u in users:
    for p in open("paths.txt").read().split():
        parts = p.strip("/").split("/")
        walk = all(bits(u, "/" + "/".join(parts[:i]))[2] == "x" for i in range(1, len(parts)))
        b = bits(u, p)
        out.append("%s,%s,%s,%s" % (u, p, "yes" if walk and b[0] == "r" else "no", "yes" if walk and b[1] == "w" else "no"))
open("matrix.csv", "w").write("\n".join(out) + "\n")
PYEOF
cat matrix.csv
